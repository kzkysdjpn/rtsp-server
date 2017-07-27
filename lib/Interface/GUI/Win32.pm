package Interface::GUI::Win32;

use Moose;
use Win32::GUI qw( WM_CLOSE WM_USER);
use Win32;
use threads;

use AnyEvent::Util;
use Socket;

use Storable;
use Storable qw(nfreeze thaw);

use JSON::PP;

has 'main_window' => (
	is => 'rw',
);

has 'setting_dialog' => (
	is => 'rw',
);

has 'app_list_view' => (
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

has 'configuration_reboot_callback' => (
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

has 'config_data_fetch_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'config_data_write_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'request_replace_code_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'config_data' => (
	is => 'rw',
	default => sub {},
);

has 'setting_cancel' => (
	is => 'rw',
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
			my $buf;
			my $len;
			my $sender_addr = recv $sock, $buf, 2048, 0;
			unless ( defined $sender_addr ){
				return;
			}
			next unless $buf;
			my @callback = (
				$self->configuration_reboot_callback,
				$self->window_terminate_callback,
			);
			my $result = thaw $buf;
			$len = $#callback;
			unless ( defined $result->{APP_CTL_OPS} ){
				return;
			}
			if( $result->{APP_CTL_OPS} < 0 ){
				return;
			}
			if ( $len < $result->{APP_CTL_OPS} ){
				return;
			}
			$callback[$result->{APP_CTL_OPS}]->();
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

	# Setup Setting Dialog.
	setup_setting_dialog(@_);

	# Setup RTSP Server Main Window.
	setup_main_window(@_);

	# $DB::single=1;
	unless($self->config_data->{INITIAL_LOAD}){
		open_setting_dialog($self);
	}

	Win32::GUI::Dialog();
	exit(0);

	return;
}

sub fetch_configration {
	my ($self) = @_;
	socket my ($sock), AF_INET, SOCK_DGRAM, 0;
	my $sock_addr = pack_sockaddr_in($self->{gui_handle}->local_control_port + 0,
						Socket::inet_aton("localhost"));
	my $data = {
		# Arbitary Defined
		# 0 - Fetch Configuration
		# 1 - Terminate App
		"APP_CTL_OPS" => 0,
	};
	my $frozen = nfreeze $data;
	send($sock, $frozen, 0, $sock_addr);
	shutdown $sock, 2;
	-1;
}

sub do_terminate_app {
	my ($self) = @_;
	socket my ($sock), AF_INET, SOCK_DGRAM, 0;
	my $sock_addr = pack_sockaddr_in($self->{gui_handle}->local_control_port + 0,
						Socket::inet_aton("localhost"));
	my $data = {
		# Arbitary Defined
		# 0 - Fetch Configuration
		# 1 - Terminate App
		"APP_CTL_OPS" => 1,
	};
	my $frozen = nfreeze $data;
	send($sock, $frozen, 0, $sock_addr);
	shutdown $sock, 2;
	-1;
}

sub setup_main_window {
	my ($self) = @_;
	my $menu = Win32::GUI::Menu->new(
		"&File"     =>            "File",
		">&Setting\tCtrl-S"     => { -name => "Source",  -onClick => \&open_setting_dialog },
		">-"        => 0,
		">E&xit"    => { -name => "Exit",    -onClick => \&do_terminate_app,},
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
		-onTerminate => \&do_terminate_app,
	));
	$self->main_window->{gui_handle} = $self;

	$self->app_list_view(
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
				my $gui_handle;
				my $dbl_clk_cmd;
				$index = $self->SelectedItems();
				unless (defined $index){
					return;
				}
#				system("taskkill /im vlc.exe");
				$dbl_clk_cmd = $self->{gui_handle}->request_replace_code_callback->(
					$self->{gui_handle}->config_data->{ON_DBLCLICK_COMMAND},
					$self->GetItemText($index, 0),
					$self->{gui_handle}->config_data->{RTSP_CLIENT_PORT},
					date_time_string(),
					$self->GetItemText($index, 4)
				);
				system("start " . $dbl_clk_cmd);
				return;
			},
		)
	);
	$self->app_list_view->{gui_handle} = $self;
	$self->app_list_view->InsertColumn(-item => 0, -text => "App. Name", -width => 100);
	$self->app_list_view->InsertColumn(-item => 1, -text => "Host Addr.", -width => 150);
	$self->app_list_view->InsertColumn(-item => 2, -text => "Start Time", -width => 150);
	$self->app_list_view->InsertColumn(-item => 3, -text => "Rec.", -width => 50);
	$self->app_list_view->InsertColumn(-item => 4, -text => "Cnt.", -width => 33);
	$self->app_list_view->Select(-1);

	# Get local IP
	my @local_addrs = map { s/^.*://; s/\s//; $_ } grep {/IPv4/} `ipconfig`;
	$local_addrs[0] =~ s/(\r\n|\r|\n)$//g;

	$self->server_address_textfield(
		$self->main_window->AddButton(
			-name => "LocalIPViewButton",
			-text => "Local PC IP and Port is " . $local_addrs[0] . ":" . $self->config_data->{RTSP_SOURCE_PORT},
			-top => 524,
			-left => 2,
			-width => 488,
			-height => 32,
			-align => 'center',
			-valign => 'center',
			-onClick => \&update_address_button,
		)
	);
	$self->server_address_textfield->{gui_handle}	= $self;

	$self->main_window->Hook(WM_USER, \&on_request_hook);
	$self->main_window->Show();
	$self->{gui_handle} = $self;
	return;
}

sub update_address_button {
	my ($self) = @_;
	my @local_addrs = map { s/^.*://; s/\s//; $_ } grep {/IPv4/} `ipconfig`;
	$local_addrs[0] =~ s/(\r\n|\r|\n)$//g;
	$self->Text("Local PC IP and Port is " . $local_addrs[0] . ":" . $self->{gui_handle}->config_data->{RTSP_SOURCE_PORT});
	return;
}

sub open_setting_dialog {
	my ($self) = @_;
	my $config_hash;
	my @avoid_field = (
		"INITIAL_LOAD",
		"USE_SOURCE_AUTH",
		"RTSP_CLIENT_PORT",
	);
	$config_hash = $self->{gui_handle}->config_data_fetch_callback->();
	foreach my $key(keys(%{$config_hash})){
		if(grep { $_ eq $key } @avoid_field ){
			next;
		}
		unless(defined $self->{gui_handle}->setting_dialog->{$key}){
			next;
		}
		my $widget = $self->{gui_handle}->setting_dialog->$key;
		$widget->SelectAll;
		$widget->Clear;
		$widget->Append($config_hash->{$key});
	}

	my $key = "USE_SOURCE_AUTH";
	my $widget = $self->{gui_handle}->setting_dialog->$key;
	if( $config_hash->{$key} ){
		$widget->SetCheck(1);
	}else{
		$widget->SetCheck(0);
	}
	$self->{gui_handle}->setting_dialog->DoModal();
	return;
}

sub setup_setting_dialog {
	my ($self) = @_;
	my $apply_btn;
	my @setting_fields = (
		"RTSP_SOURCE_PORT",
		"ON_DBLCLICK_COMMAND",
		"ON_RECEIVE_COMMAND",
		"RTP_START_PORT",
		"USE_SOURCE_AUTH",
		"SOURCE_AUTH_USERNAME",
		"SOURCE_AUTH_PASSWORD",
	);
	my $cancel;

	$self->setting_dialog(Win32::GUI::Window->new(
		-name => 'Setting',
		-title => 'RTSP-Server Setting',
		-text => 'RTSP-Server Setting',
		-top => 60,
		-left => 60,
		-width => 500,
		-height => 600,
		-resizable => 0,
		-hasmaximize => 0,
		-maximizebox => 0,
		-hasminimize => 0,
		-minimizebox => 0,
		-sizable => 0,
		-dialogui => 1,
		-titlebar => 0,
		-sysmenu => 0,
		-menubox => 0,
		-parent => $self->main_window,
	));
	$self->setting_dialog->AddLabel(
		-name   => "SettingViewSourcePortLabel",
		-text   => "RTSP Source Port",
		-left   => 2,
		-top    => 12,
		-width  => 140,
		-height => 32,
		-align  => 'center',
	);
	$self->setting_dialog->AddTextfield(
		-name   => "RTSP_SOURCE_PORT",
		-text   => "",
		-left   => 150,
		-top    => 12,
		-width  => 340,
		-height => 32,
		-valign => 'center',
	);

	$self->setting_dialog->AddLabel(
		-name   => "SettingViewDblClickCommandLabel",
		-text   => "On Double Click Command",
		-left   => 2,
		-top    => 48,
		-width  => 140,
		-height => 80,
		-align  => 'center',
	);
	$self->setting_dialog->AddTextfield(
		-name   => "ON_DBLCLICK_COMMAND",
		-text   => "",
		-left   => 150,
		-top    => 48,
		-width  => 298,
		-height => 80,
		-valign => 'center',
		-multiline => 1,
	);
	$self->setting_dialog->AddButton(
		-name   => "SettingViewOnDblClickCommandButton",
		-text   => "?",
		-left   => 452,
		-top    => 48,
		-width  => 36,
		-height => 80,
	);

	$self->setting_dialog->AddLabel(
		-name   => "SettingViewOnReceiveCommandLabel",
		-text   => "On Receive Command",
		-left   => 2,
		-top    => 132,
		-width  => 140,
		-height => 80,
		-align  => 'center',
	);
	$self->setting_dialog->AddTextfield(
		-name   => "ON_RECEIVE_COMMAND",
		-text   => "",
		-left   => 150,
		-top    => 132,
		-width  => 298,
		-height => 80,
		-valign => 'center',
		-multiline => 1,
	);
	$self->setting_dialog->AddButton(
		-name   => "SettingViewOnReceiveCommandButton",
		-text   => "?",
		-left   => 452,
		-top    => 132,
		-width  => 36,
		-height => 80,
	);

	$self->setting_dialog->AddLabel(
		-name   => "SettingViewRTPStartPortLabel",
		-text   => "RTP Start Port",
		-left   => 2,
		-top    => 228,
		-width  => 140,
		-height => 32,
		-align  => 'center',
	);
	$self->setting_dialog->AddTextfield(
		-name   => "RTP_START_PORT",
		-text   => "",
		-left   => 150,
		-top    => 228,
		-width  => 340,
		-height => 32,
		-valign => 'center',
	);

	$self->setting_dialog->AddCheckbox(
		-name   => "USE_SOURCE_AUTH",
		-text   => "Use Source Authentication",
		-left   => 2,
		-top    => 264,
		-width  => 180,
		-height => 32,
		-align  => 'center',
	);

	$self->setting_dialog->AddLabel(
		-name   => "SettingViewSourceAuthUserNameLabel",
		-text   => "Source User Name",
		-left   => 2,
		-top    => 300,
		-width  => 140,
		-height => 32,
		-align  => 'center',
	);
	$self->setting_dialog->AddTextfield(
		-name   => "SOURCE_AUTH_USERNAME",
		-text   => "",
		-left   => 150,
		-top    => 300,
		-width  => 340,
		-height => 32,
		-valign => 'center',
	);

	$self->setting_dialog->AddLabel(
		-name   => "SettingViewSourceAuthPasswordLabel",
		-text   => "Source Password",
		-left   => 2,
		-top    => 336,
		-width  => 140,
		-height => 32,
		-align  => 'center',
	);
	$self->setting_dialog->AddTextfield(
		-name   => "SOURCE_AUTH_PASSWORD",
		-text   => "",
		-left   => 150,
		-top    => 336,
		-width  => 340,
		-height => 32,
		-valign => 'center',
	);

	$cancel = $self->setting_dialog->AddButton(
		-name => "SettingView",
		-text => "Cancel",
		-top => 538,
		-left => 2,
		-width => 244,
		-height => 32,
		-onClick => sub {
			my ($self) = @_;
			-1;
		},
	);
	$apply_btn = $self->setting_dialog->AddButton(
		-name => "SettingViewApplyButton",
		-text => "Apply",
		-top => 538,
		-left => 248,
		-width => 242,
		-height => 32,
		-onClick => \&apply_setting,
	);
	foreach my $var(@setting_fields){
		$apply_btn->{$var} = $self->setting_dialog->$var;
	}
	$apply_btn->{gui_handle} = $self;
	unless($self->config_data->{INITIAL_LOAD}){
		$cancel->Hide();
	}
	$self->setting_cancel($cancel);
	return;
}

sub apply_setting {
	my ($self) = @_;
	my $config_hash;
	my @text_fields = (
		"RTSP_SOURCE_PORT",
		"ON_DBLCLICK_COMMAND",
		"ON_RECEIVE_COMMAND",
		"RTP_START_PORT",
		"SOURCE_AUTH_USERNAME",
		"SOURCE_AUTH_PASSWORD",
	);
	my @checkbox_fields = (
		"USE_SOURCE_AUTH",
	);
	$config_hash = $self->{gui_handle}->config_data_fetch_callback->();
	foreach my $var(@text_fields){
		unless( defined $self->{$var} ){
			next;
		}
		$config_hash->{$var} = $self->{$var}->Text();
	}
	foreach my $var(@checkbox_fields){
		unless($self->{$var}->GetCheck()){
			$config_hash->{$var} = JSON::PP::false;
			next;
		}
		$config_hash->{$var} = JSON::PP::true;
	}

	$config_hash->{INITIAL_LOAD} = JSON::PP::true;

	update_address_button($self->{gui_handle}->server_address_textfield);

	$self->{gui_handle}->config_data_write_callback->($config_hash);
	$self->{gui_handle}->setting_cancel->Show();
	$self->{gui_handle}->config_data($config_hash);
	$self->{gui_handle}->fetch_configration();
	-1;
}

sub on_request_hook {
	my ($self, $len, $data) = @_;
	my $frozen = unpack("P$len", pack('Q', $data));
	my $result = thaw $frozen;
	my $source_name = substr $$result{APPLICATION}, 1;

	if($$result{OPS} == 0){ # Remove application process.
		my $find_item = $self->AppListView->FindItem(
			-1,
			-string => $source_name,
		);
		if ($find_item < 0){
			return;
		}
		$self->AppListView->DeleteItem($find_item);
		return;
	}

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;

	my $pid = exec_on_receive_command($self, $source_name, $$result{COUNT});
	# Add application process.
	my $date = sprintf("%04d/%02d/%02d %02d:%02d:%02d" ,$year,$mon,$mday,$hour,$min,$sec);
	my $ret = $self->AppListView->InsertItem(-text => [$source_name, $$result{HOST}, $date, $pid, $$result{COUNT}]);
	return;
}

sub exec_on_receive_command {
	my ($self, $source_name, $source_count) = @_;
	my $on_recv_cmd;
	$on_recv_cmd = $self->{gui_handle}->request_replace_code_callback->(
					$self->{gui_handle}->config_data->{ON_RECEIVE_COMMAND},
					$source_name,
					$self->{gui_handle}->config_data->{RTSP_CLIENT_PORT},
					date_time_string(),
					$source_count
		);
	my $pid = system(1, "start " . $on_recv_cmd);
	return $pid;
}

sub date_time_string {
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date_time = sprintf("%04d%02d%02d%02d%02d%02d" ,$year,$mon,$mday,$hour,$min,$sec);
	return $date_time;
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
