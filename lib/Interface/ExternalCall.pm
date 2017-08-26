package Interface::ExternalCall;

use Moose;
use UNIVERSAL::require;

has 'external_command_line' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has 'external_process_id' => (
	is => 'rw',
);

sub open
{
	return 0;
}

sub process_launch_main
{
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
	return;
}
