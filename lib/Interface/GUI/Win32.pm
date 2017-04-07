package Interface::GUI::Win32;

use Moose;
use Win32::GUI qw( WM_CLOSE WM_USER);
use threads;

use AnyEvent::Util;
use Socket;

use Storable;
use Storable qw(nfreeze thaw);

has 'main_window' => (
	is => 'rw',
);

has 'mount_list_view' => (
	is => 'rw',
);

has 'server_address_textfield' => (
	is => 'rw',
);

has 'mw_height' => (
	is => 'rw',
	isa => 'Int',
	default => 600,
);

has 'mw_width' => (
	is => 'rw',
	isa => 'Int',
	default => 400,
);

has 'window_terminate_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'watcher' => (
	is => 'rw',
	clearer => 'clear_watcher',
);

has 'gui_thread_obj' => (
	is => 'rw',
);

has 'main_window_title' => (
	is => 'rw',
	default => 'RTSP-Server',
);

has 'close_event' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'local_control_port' => (
	is => 'rw',
	isa => 'Int',
	default => 65432,
);

has 'local_control_socket' => (
	is => 'rw',
);

has 'vlc_directory_path' => (
	is => 'rw',
	default => 'C:\\PROGRA~1\\VideoLAN\\VLC\\',
);

sub open {
	my ($self) = @_;

	socket my ($sock), AF_INET, SOCK_DGRAM, 0;
	AnyEvent::Util::fh_nonblocking $sock, 1;
	my $addr = sockaddr_in($self->local_control_port, Socket::inet_aton("localhost"));
	unless ( bind $sock, $addr ){
		return 0;
	}
	$self->local_control_socket($sock);
	my $w = AnyEvent->io(
		fh => $sock,
		poll => 'r',
		cb => sub {
			$self->window_terminate_callback->();
			return;
		}
	);
	$self->watcher($w);

	# Create Windows GUI interface thread.
	my $thread = threads->new(\&open_gui_widget, @_);
	$self->gui_thread_obj($thread);
	return 1;
}

sub open_gui_widget {
	my ($self) = @_;

	my $menu = Win32::GUI::Menu->new(
		"&File"     =>            "File",
		">&Setting\tCtrl-S"     => { -name => "Source",  -onClick => \&showSetting },
		">-"        => 0,
		">E&xit"    => { -name => "Exit",    -onClick => sub {
			socket my ($sock), AF_INET, SOCK_DGRAM, 0;
			my $sock_addr = pack_sockaddr_in($self->local_control_port, Socket::inet_aton("localhost"));
			send($sock, "terminate\n", 0, $sock_addr);
			shutdown $sock, 2;
			-1
		},},
		"&Help"     =>            "HelpB",
		">&Help\tF1"           => { -name => "Help",    -onClick => \&showHelp, },
		">&About..."           => { -name => "About",   -onClick => \&showAboutBox, },
	);

	$self->main_window(Win32::GUI::Window->new(
		-name => 'Main',
		-title => $self->main_window_title,
		-text => $self->main_window_title,
		-menu => $menu,
		-top => 60,
		-left => 60,
		-width => 500,
		-height => 600,
		-resizable => 0,
		-hasmaximize => 0,
		-maximizebox => 0,
		-onTerminate => sub {
			socket my ($sock), AF_INET, SOCK_DGRAM, 0;
			my $sock_addr = pack_sockaddr_in($self->local_control_port, Socket::inet_aton("localhost"));
			send($sock, "terminate\n", 0, $sock_addr);
			shutdown $sock, 2;
			-1;
		},
	));

	$self->mount_list_view(
		$self->main_window->AddListView(
			-name => "AppListView",
			-text => "&App List View",
			-top => 0,
			-left => 2,
			-vscroll => 1,
			-width => 488,
			-height => 520,
			-multisel => 0,
			-gridlines => 1,
			-fullrowselect => 1,
			-onClick => sub {
				return;
			},
			-onMouseDblClick => sub {
				my ($self) = @_;
				my $index;
				$index = $self->SelectedItems();
				unless (defined $index){
					return;
				}
#				$DB::single=1;
				system("taskkill /im vlc.exe");
				system("start " . $self->{vlc_directory_path} . "vlc.exe");
				print "onClick() " . $self->GetItemText($index, 2) . "\n";
				return;
			},
		)
	);

	$self->mount_list_view->{vlc_directory_path} = $self->vlc_directory_path;

	$self->mount_list_view->InsertColumn(-item => 0, -text => "App. Name", -width => 100);
	$self->mount_list_view->InsertColumn(-item => 1, -text => "Host Addr.", -width => 150);
	$self->mount_list_view->InsertColumn(-item => 2, -text => "Start Time", -width => 150);
	$self->mount_list_view->InsertColumn(-item => 3, -text => "Rec.", -width => 50);
	$self->mount_list_view->InsertColumn(-item => 4, -text => "Cnt.", -width => 33);
	$self->mount_list_view->Select(-1);

	# Get local IP
	my @local_addrs = map { s/^.*://; s/\s//; $_ } grep {/IPv4/} `ipconfig`;
	$local_addrs[0] =~ s/(\r\n|\r|\n)$//g;
	$DB::single=1;

	$self->server_address_textfield(
		$self->main_window->AddTextfield(
			-name => "ServerAddressTextfield",
			-text => $local_addrs[0],
			-top => 520,
			-left => 2,
			-width => 488,
			-height => 34,
			-align => 'center',
			-readonly => 1,
			-valign => 'center',
			-wantreturn => 0,
		)
	);
	$self->main_window->Hook(WM_USER, \&on_request_hook);

	$self->main_window->Show();
	Win32::GUI::Dialog();
	exit(0);
	return;
}

sub on_request_hook {
	my ($self, $len, $data) = @_;
	my $frozen = unpack("P$len", pack('Q', $data));
	my $result = thaw $frozen;
	my $trim_name = substr $$result{APPLICATION}, 1;
	if($$result{OPS} == 0){
#		$DB::single=1;
		return;
	}
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date = sprintf("%04d/%02d/%02d %02d:%02d:%02d" ,$year,$mon,$mday,$hour,$min,$sec);
	my $ret = $self->AppListView->InsertItem(-text => [$trim_name, $$result{HOST}, $date, "", $$result{COUNT}]);
	return;
}

sub close {
	my ($self) = @_;
	$self->gui_thread_obj->join;
	return;
}

sub clear_application {
	return;
}

sub add_application {
	my ($self, $mount, $count) = @_;

	my $window = Win32::GUI::FindWindow('', $self->main_window_title);
	my $data = {
		# Arbitary Defined
		# 0 - Remove Application
		# 1 - Add Application
		"OPS" => 1,
		"APPLICATION" => $mount->path,
		"HOST" => $mount->source_host,
		"COUNT" => $count,
	};
	my $frozen = nfreeze $data;
	Win32::GUI::PostMessage($window, WM_USER, length $frozen, $frozen);
	return;
}

sub remove_application {
	my ($self, $app_path, $count) = @_;

	my $window = Win32::GUI::FindWindow('', $self->main_window_title);
	my $data = {
		# Arbitary Defined
		# 0 - Remove Application
		# 1 - Add Application
		"OPS" => 0,
		"APPLICATION" => $app_path,
		"HOST" => "",
		"COUNT" => $count,
	};
	my $frozen = nfreeze $data;
	Win32::GUI::PostMessage($window, WM_USER, length $frozen, $frozen);
	return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME
