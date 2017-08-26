package Interface::ExternalCall;

use Moose;
use UNIVERSAL::require;
use Socket;
use IO::Handle;
has 'external_command_line' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has 'launch_main_process' => (
	is => 'rw',
);

has 'signal_launch_main' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);

has 'external_process_id' => (
	is => 'rw',
);

has 'child_pipe' => (
	is => 'rw',
);

has 'parent_pipe' => (
	is => 'rw',
);

sub open
{
	my $child_pipe;
	my $parent_pipe;
	unless( $^O eq "MSWin32"){
		return 1;
	}
	socketpair($child_pipe, $parent_pipe, AF_UNIX, SOCK_STREAM, PF_UNSPEC) || return 0;
	$child_pipe->autoflush(1);
	$self->child_pipe($child_pipe);
	$child_pipe = undef;
	$parent_pipe->autoflush(1);
	$self->parent_pipe($parent_pipe);
	$parent_pipe = undef;

	$pid = fork;
	unless($pid){
		$self->child_pipe;
		$self->process_launch_main;
		exit;
	}
	$self->launch_main_process($pid);
	close $self->parent_pipe;
	return 1;
}

sub process_launch_main
{
	while (! $self->signal_launch_main ){
	}
	return;
}

sub execute_process
{
	my $process;
	my ($filename, $args) = split(/ / , $self->external_command_line, 2);
	if ( $^O eq "MSWin32"){
		Win32::Process:Create($process, $filename, " " . $args, 0, 'CREATE_NEW_CONSOLE', ".") || return 0;
		$self->external_process_id($process);
		return 1;
	}

	$process = fork();
	unless(defined $process){
		return 0;
	}
	unless($process){
		exec($self->external_command_line);
	}
	$self->external_process_id($process);
	return 1;
}

sub close
{
	close $self->child_pipe;
	waitpid $self->launch_main_process;
	return;
}
