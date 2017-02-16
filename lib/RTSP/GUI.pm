package RTSP::GUI;

use Moose;
use Tk;

has 'main_window' => (
	is => 'rw',
);

has 'mount_list_box' => (
	is => 'rw',
);

has 'height' => (
	is => 'rw',
	isa => 'Int',
	default => 40,
);

has 'width' => (
	is => 'rw',
	isa => 'Int',
	default => 80,
);

has 'close_event' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

sub open {
	my ($self) = @_;
	$self->main_window(MainWindow->new);
	$self->mount_list_box($self->main_window->Scrolled('Listbox',
			-scrollbars=> 'osoe',
			-height =>  $self->height,
			-width =>  $self->width,
			-background => 'white',
			-selectforeground => 'brown',
			-selectbackground => 'cyan',
			-selectmode=> 'extended')->pack(
				-fill =>'both',
				-expand => 'yes'));
	$self->main_window->protocol('WM_DELETE_WINDOW', \$self->close_event);
	return 1;
}

sub close {
	return;
}

sub clear_mount_element {
	my ($self) = @_;
	$self->mount_list_box->delete(0, 'end');
	return;
}

sub add_mount_element {
	my ($self, $mount_element) = @_;
	$self->mount_list_box->insert('end', $mount_element);
	return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME
