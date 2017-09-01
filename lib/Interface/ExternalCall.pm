package Interface::ExternalCall;

use Moose;
use Socket;
use IO::Handle;

use Storable;
use Storable qw(nfreeze thaw);

use UNIVERSAL::require;

use POSIX ":sys_wait_h";

has 'external_command_line' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has 'terminate_process_id' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);

has 'reply_status' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);

has 'main_process_id' => (
	is => 'rw',
);

has 'signal_launch_main' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);

has 'external_process_ids' => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { [] },
);

has 'child_out_pipe' => (
	is => 'rw',
);

has 'child_in_pipe' => (
	is => 'rw',
);

has 'parent_out_pipe' => (
	is => 'rw',
);

has 'parent_in_pipe' => (
	is => 'rw',
);

sub open
{
	my ($self) = @_;
	my $child_in_pipe;
	my $child_out_pipe;
	my $parent_in_pipe;
	my $parent_out_pipe;

	if( $^O eq "MSWin32"){
		"Win32::Process"->require;
		"Win32"->require;
		return 1;
	}
	pipe($child_in_pipe, $parent_out_pipe);
	pipe($parent_in_pipe, $child_out_pipe);

	$child_in_pipe->autoflush(1);
	$parent_in_pipe->autoflush(1);

	$self->child_in_pipe($child_in_pipe);
	$self->child_out_pipe($child_out_pipe);
	$self->parent_in_pipe($parent_in_pipe);
	$self->parent_out_pipe($parent_out_pipe);
	my $pid = fork;
	unless($pid){
		close $self->child_in_pipe;
		close $self->child_out_pipe;
		$self->process_launch_main;
		close $self->parent_in_pipe;
		close $self->parent_out_pipe;
		exit;
	}
	$self->main_process_id($pid);
	close $self->parent_in_pipe;
	close $self->parent_out_pipe;
	return 1;
}

sub process_launch_main
{
	my ($self) = @_;
	my $fds_in;
	my $fds_out;
	my $frozen;
	my $data;
	my @process_control = (
		\&start_new_process,
		\&terminate_process,
		\&terminate_all_process,
		\&terminate_main_process,
	);
	vec($fds_in, fileno($self->parent_in_pipe), 1) = 1;
	$fds_out = $fds_in;
	while (! $self->signal_launch_main ){
		if(select($fds_out, undef, undef, 1) <= 0){
			$fds_out = $fds_in;
			next;
		}
		if(! vec($fds_out, fileno($self->parent_in_pipe), 1)){
			$fds_out = $fds_in;
			next;
		}
		sysread($self->parent_in_pipe, $frozen, 2048);
		$data = thaw $frozen;
		$fds_out = $fds_in;
		# 0 - Start New Process
		# 1 - Terminate Process
		# 2 - Terminate All Process
		# 3 - Exit Main Process and Terminate All Process
		if($data->{OPS} < 0){
			next;
		}
		if($data->{OPS} > 3){
			next;
		}
		my $ret = {
			'PID' => 0,
		};
		$ret->{PID} = $process_control[$data->{OPS}]->($self, $data->{CMD}, $data->{PID});
		$frozen = nfreeze $ret;
		syswrite($self->parent_out_pipe, $frozen, length($frozen));
	}
	return;
}

sub start_new_process
{
	my ($self, $cmd_line, undef) = @_;
	my $process_ids;
	my $i;
	my $pid = fork();
	unless(defined $pid){
		return 0;
	}
	unless($pid){
		exec($cmd_line);
	}
	$process_ids = $self->external_process_ids;
	push(@$process_ids, $pid);
	$self->external_process_ids($process_ids);
	return $pid;
}

sub terminate_process
{
	my ($self, undef, $terminate_process_id) = @_;
	my $i;
	my $process_ids;
	my $pid;
	$process_ids = $self->external_process_ids;
	for($i = 0; $i < scalar(@$process_ids); $i++){
		$pid = @$process_ids[$i];
		if($pid == $terminate_process_id){
			splice(@$process_ids, $i, 1);
			kill('SIGKILL', $terminate_process_id);
			waitpid($terminate_process_id, WNOHANG);
		}
	}
	$self->external_process_ids($process_ids);
	return 0;
}

sub terminate_all_process
{
	my ($self, undef, undef) = @_;
	my $i;
	my $process_ids;
	my @empty_array = ();
	$process_ids = $self->external_process_ids;

	for($i = 0; $i < scalar(@$process_ids); $i++){
		kill('SIGKILL', @$process_ids[$i]);
		waitpid(@$process_ids[$i], WNOHANG);
	}
	$self->external_process_ids(\@empty_array);
	return 0;
}

sub terminate_main_process
{
	my ($self, undef, undef) = @_;
	$self->terminate_all_process(@_);
	$self->signal_launch_main(1);
	return 0;
}

sub start_process
{
	my ($self) = @_;
	my $pid;
	my $process_ids;
	my $fds_in;
	my $fds_out;
	my $frozen;
	my $reply;
	if ( $^O eq "MSWin32"){
		my ($filename, $args) = split(/ / , $self->external_command_line, 2);
		$args = ' ' . $args;
		my $flag = Win32::Process::CREATE_NEW_CONSOLE();
		Win32::Process::Create($pid, $filename, $args, 0, $flag, ".") || return 0;
		$process_ids = $self->external_process_ids;
		push(@$process_ids, $pid);
		$self->external_process_ids($process_ids);
		$self->reply_status($pid->GetProcessID());
		return 1;
	}
	my $data = {
		'OPS' => 0,
		'CMD' => $self->external_command_line,
		'PID' => 0,
	};
	$frozen = nfreeze $data;
	syswrite($self->child_out_pipe, $frozen, length($frozen));

	# Reply from Child Process.
	vec($fds_in, fileno($self->child_in_pipe), 1) = 1;
	$fds_out = $fds_in;
	if(select($fds_out, undef, undef, 3) <= 0){
		return 0;
	}
	if(! vec($fds_out, fileno($self->child_in_pipe), 1)){
		return 0;
	}
	sysread($self->child_in_pipe, $frozen, 2048);
	$reply = thaw $frozen;
	$self->reply_status($reply->{PID});
	return 1;
}

sub stop_process
{
	my ($self) = @_;
	my $i;
	my $process_ids;
	my $pid;
	if ( $^O eq "MSWin32"){
		$pid = undef;
		$process_ids = $self->external_process_ids;
		for($i = 0; $i < scalar(@$process_ids); $i++){
			$pid = @$process_ids[$i];
			if($pid->GetProcessID() == $self->terminate_process_id){
				splice(@$process_ids, $i, 1);
				$pid->Kill(0);
				$pid = undef;
			}
		}
		return;
	}
	my $data = {
		'OPS' => 1,
		'CMD' => "",
		'PID' => $self->terminate_process_id,
	};
	my $frozen = nfreeze $data;
	my $fds_in;
	my $fds_out;
	syswrite($self->child_out_pipe, $frozen, length($frozen));

	# Reply from Child Process.
	vec($fds_in, fileno($self->child_in_pipe), 1) = 1;
	$fds_out = $fds_in;
	if(select($fds_out, undef, undef, 3) <= 0){
		return;
	}
	if(! vec($fds_out, fileno($self->child_in_pipe), 1)){
		return;
	}
	sysread($self->child_in_pipe, $frozen, 2048);
	my $reply = thaw $frozen;
	$self->reply_status($reply->{PID});
	return;
}

sub stop_all_process
{
	my ($self) = @_;
	my $process_ids;
	my @empty_array = ();
	if ( $^O eq "MSWin32"){
		my $i;
		$process_ids = $self->external_process_ids;
		for($i = 0; $i < scalar(@$process_ids); $i++){
			@$process_ids[$i]->Kill(0);
		}
		$self->external_process_ids(\@empty_array);
		return;
	}
	my $data = {
		'OPS' => 2,
		'CMD' => "",
		'PID' => 0,
	};
	my $fds_in;
	my $fds_out;
	my $frozen = nfreeze $data;
	syswrite($self->child_out_pipe, $frozen, length($frozen));

	# Reply from Child Process.
	vec($fds_in, fileno($self->child_in_pipe), 1) = 1;
	$fds_out = $fds_in;
	if(select($fds_out, undef, undef, 3) <= 0){
		return;
	}
	if(! vec($fds_out, fileno($self->child_in_pipe), 1)){
		return;
	}
	sysread($self->child_in_pipe, $frozen, 2048);
	my $reply = thaw $frozen;
	$self->reply_status($reply->{PID});

	return;
}

sub close
{
	my ($self) = @_;
	my $fds_in;
	my $fds_out;
	if( $^O eq "MSWin32"){
		$self->stop_all_process;
		return;
	}
	my $data = {
		'OPS' => 3,
		'CMD' => '',
		'PID' => 0,
	};
	my $frozen = nfreeze $data;

	syswrite($self->child_out_pipe, $frozen, length($frozen));

	# Reply from Child Process.
	vec($fds_in, fileno($self->child_in_pipe), 1) = 1;
	$fds_out = $fds_in;
	if(select($fds_out, undef, undef, 3) <= 0){
		return;
	}
	if(! vec($fds_out, fileno($self->child_in_pipe), 1)){
		return;
	}
	sysread($self->child_in_pipe, $frozen, 2048);
	my $reply = thaw $frozen;
	$self->reply_status($reply->{PID});

	waitpid($self->main_process_id, WNOHANG);

	close $self->child_in_pipe;
	close $self->child_out_pipe;
	return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME
