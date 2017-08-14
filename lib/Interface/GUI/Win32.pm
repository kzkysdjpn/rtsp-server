package Interface::GUI::Win32;

use Moose;
use Win32::GUI qw( WM_CLOSE WM_USER);
use Win32::Process;
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

has 'auth_list_view' => (
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

has 'source_remove_user' => (
	is => 'rw',
);

has 'source_add_user' => (
	is => 'rw',
);

has 'on_receive_process_list' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub { {} },
	lazy => 1,
);

has 'on_dblclk_process' => (
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

sub reboot_configration {
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
				my $newProc;
				my $oldProc;
				$index = $self->SelectedItems();
				unless (defined $index){
					return;
				}
				$oldProc = $self->{gui_handle}->on_dblclk_process;
				if (defined $oldProc ){
					$oldProc->Kill(0);
					$oldProc = undef;
					$self->{gui_handle}->on_dblclk_process($oldProc);
				}
#				system("taskkill /im vlc.exe");
				$dbl_clk_cmd = $self->{gui_handle}->request_replace_code_callback->(
					$self->{gui_handle}->config_data->{ON_DBLCLICK_COMMAND},
					$self->GetItemText($index, 0),
					$self->{gui_handle}->config_data->{RTSP_CLIENT_PORT},
					date_time_string(),
					$self->GetItemText($index, 4)
				);
				my ($exec_file, $args) = split(/ /, $dbl_clk_cmd, 2);
				Win32::Process::Create($newProc, $exec_file, " " . $args, 0, CREATE_NO_WINDOW, ".") || die ErrorReport();
				$self->{gui_handle}->on_dblclk_process($newProc);
				return;
			},
		)
	);
	$self->app_list_view->{gui_handle} = $self;
	$self->app_list_view->InsertColumn(-item => 0, -text => "App. Name", -width => 100);
	$self->app_list_view->InsertColumn(-item => 1, -text => "Host Addr.", -width => 150);
	$self->app_list_view->InsertColumn(-item => 2, -text => "Start Time", -width => 150);
	$self->app_list_view->InsertColumn(-item => 3, -text => "Cmd.", -width => 50);
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

sub load_source_user_info {
	my ($self, $user_info) = @_;
	$self->{gui_handle}->auth_list_view->DeleteAllItems();
	$self->{gui_handle}->auth_list_view->{SOURCE_USERNAME}->SelectAll;
	$self->{gui_handle}->auth_list_view->{SOURCE_USERNAME}->Clear;
	$self->{gui_handle}->auth_list_view->{SOURCE_PASSWORD}->SelectAll;
	$self->{gui_handle}->auth_list_view->{SOURCE_PASSWORD}->Clear;
	$self->{gui_handle}->auth_list_view->{SOURCE_MOUNT}->SelectAll;
	$self->{gui_handle}->auth_list_view->{SOURCE_MOUNT}->Clear;
	for my $href ( @$user_info ) {
		$self->{gui_handle}->auth_list_view->InsertItem(
			-text => [
				$$href{USERNAME},
				$$href{MOUNT_PATH}
			]
		);
	}
	$self->{gui_handle}->auth_list_view->{source_auth_list} = $user_info;
	1;
}

sub open_setting_dialog {
	my ($self) = @_;
	my $config_hash;
	my @avoid_field = (
		"INITIAL_LOAD",
		"USE_SOURCE_AUTH",
		"RTSP_CLIENT_PORT",
		"SOURCE_AUTH_INFO_LIST",
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
	load_source_user_info($self, $config_hash->{SOURCE_AUTH_INFO_LIST});
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
		-width  => 340,
		-height => 80,
		-valign => 'center',
		-multiline => 1,
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
		-width  => 340,
		-height => 80,
		-valign => 'center',
		-multiline => 1,
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

	# Authentication Parameter.
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
		-name   => "SourceUserNameLabel",
		-text   => "User Name",
		-left   => 2,
		-top    => 300,
		-width  => 180,
		-height => 32,
		-align  => 'center',
	);
	my $source_user = $self->setting_dialog->AddTextfield(
		-name   => "SOURCE_USER_NAME",
		-text   => "",
		-left   => 2,
		-top    => 332,
		-width  => 180,
		-height => 32,
	);

	$self->setting_dialog->AddLabel(
		-name   => "SourcePasswordLabel",
		-text   => "Password",
		-left   => 184,
		-top    => 300,
		-width  => 180,
		-height => 32,
		-align  => 'center',
	);
	my $source_pass = $self->setting_dialog->AddTextfield(
		-name     => "SOURCE_PASSWORD",
		-text     => "",
		-left     => 184,
		-top      => 332,
		-width    => 178,
		-height   => 32,
		-password => 1,
	);

	$self->setting_dialog->AddLabel(
		-name   => "SourceMountPathLabel",
		-text   => "Mount Path",
		-left   => 364,
		-top    => 300,
		-width  => 120,
		-height => 32,
		-align  => 'center',
	);
	my $source_mount = $self->setting_dialog->AddTextfield(
		-name     => "SOURCE_MOUNT_PATH",
		-text     => "",
		-left     => 364,
		-top      => 332,
		-width    => 120,
		-height   => 32,
	);
	my $remove_user = $self->setting_dialog->AddButton(
		-name => "SOURCE_REMOVE_USER",
		-text => "Remove User",
		-top => 368,
		-left => 2,
		-width => 238,
		-height => 32,
		-onClick => sub {
			my ($self) = @_;
			my $auth_list;
			my $list_view = $self->{gui_handle}->auth_list_view;
			unless ( defined $list_view ) {
				return;
			}
			$auth_list = $list_view->{source_auth_list};
			unless ( defined $auth_list ){
				return;
			}
			my $index = $list_view->SelectedItems();
			unless ( defined $index ){
				return;
			}
			$list_view->DeleteItem($index);
			splice(@$auth_list, $index, 1);
			$list_view->{source_auth_list} = $auth_list;
			1;
		},
	);
	$remove_user->{gui_handle} = $self;
	$self->source_remove_user($remove_user);

	my $add_user = $self->setting_dialog->AddButton(
		-name => "SOURCE_ADD_USER",
		-text => "Add User",
		-top => 368,
		-left => 242,
		-width => 240,
		-height => 32,
		-onClick => sub {
			my ($self) = @_;
			my $auth_list;
			my $is_conflict_user;
			my $list_view = $self->{gui_handle}->auth_list_view;
			my @widgets = (
				$list_view->{SOURCE_USERNAME},
				$list_view->{SOURCE_PASSWORD},
				$list_view->{SOURCE_MOUNT},
			);
			my $error;
			unless ( defined $list_view ) {
				return;
			}
			$auth_list = $list_view->{source_auth_list};
			unless ( defined $auth_list ){
				return;
			}
			$is_conflict_user = 0;
			foreach my $href ( @$auth_list ) {
				if ( $widgets[0]->Text() ne $$href{USERNAME} ){
					next;
				}
				$is_conflict_user = 1;
				last;
			}
			if($is_conflict_user){
				Win32::GUI::MessageBox($self, "Conflict exist user name.", "Error", 0x001000);
				return;
			}
			$error = 0;
			for(my $i = 0; $i < 2; $i++) {
				if( length($widgets[$i]->Text()) ){
					next;
				}
				$error = 1;
				last;
			}
			if($error){
				Win32::GUI::MessageBox($self, "Empty user name or password.", "Error", 0x001000);
				return;
			}

			$list_view->InsertItem(
				-text => [
					$widgets[0]->Text(),
					$widgets[2]->Text(),
				]
			);

			my %new_user = (
				"USERNAME"   => $widgets[0]->Text(),
				"PASSWORD"   => $widgets[1]->Text(),
				"MOUNT_PATH" => $widgets[2]->Text(),
			);
			push(@$auth_list, \%new_user);
			$list_view->{source_auth_list} = $auth_list;

			1;
		},
	);
	$add_user->{gui_handle} = $self;
	$self->source_add_user($add_user);

	$self->auth_list_view(
		$self->setting_dialog->AddListView(
			-name          => "AuthUserInfoView",
			-text          => "&Authentication List View",
			-left          => 2,
			-top           => 408,
			-width         => 486,
			-height        => 112,
			-vscroll       => 1,
			-multisel      => 0,
			-gridlines     => 1,
			-fullrowselect => 1,
			-onClick       => sub {
				my $index;
				my $aref;
				my $href;
				my $auth_list;
				$auth_list = $self->auth_list_view;
				$index = $auth_list->SelectedItems();
				unless (defined $index){
					return;
				}
				$aref = $auth_list->{source_auth_list};
				unless(defined $aref){
					return;
				}
				$href = @$aref[$index];
				my @widgets = (
					$self->auth_list_view->{SOURCE_USERNAME},
					$self->auth_list_view->{SOURCE_PASSWORD},
					$self->auth_list_view->{SOURCE_MOUNT},
				);
				my @config_name = (
					'USERNAME',
					'PASSWORD',
					'MOUNT_PATH',
				);
				foreach my $i(0 .. $#widgets){
					$widgets[$i]->SelectAll;
					$widgets[$i]->Clear;
					$widgets[$i]->Append($$href{$config_name[$i]});
				}
				return;
			},
		)
	);
	$self->auth_list_view->{gui_handle} = $self;
	$self->auth_list_view->InsertColumn(-item => 0, -text => "User Name", -width => 240);
	$self->auth_list_view->InsertColumn(-item => 2, -text => "Mount Path", -width => 240);

	$self->auth_list_view->{SOURCE_USERNAME} = $source_user;
	$self->auth_list_view->{SOURCE_PASSWORD} = $source_pass;
	$self->auth_list_view->{SOURCE_MOUNT} = $source_mount;

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
		"ON_DBLCLICK_COMMAND",
		"ON_RECEIVE_COMMAND",
		"RTP_START_PORT",
	);
	my @checkbox_fields = (
		"USE_SOURCE_AUTH",
	);
	$config_hash = $self->{gui_handle}->config_data_fetch_callback->();

	check_rtsp_source_and_client_port($self, $config_hash);

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

	$config_hash->{SOURCE_AUTH_INFO_LIST} = $self->{gui_handle}->auth_list_view->{source_auth_list};
	$self->{gui_handle}->config_data_write_callback->($config_hash);

	$self->{gui_handle}->setting_cancel->Show();
	$self->{gui_handle}->config_data($config_hash);
	$self->{gui_handle}->reboot_configration();

	update_address_button($self->{gui_handle}->server_address_textfield);

	-1;
}

sub check_rtsp_source_and_client_port {
	my ($self, $config_hash) = @_;
	my $rtsp_client_port = $config_hash->{RTSP_CLIENT_PORT} . "";
	my $rtsp_source_port = $self->{RTSP_SOURCE_PORT}->Text();
	if($rtsp_client_port eq $rtsp_source_port){
		return;
	}
	$config_hash->{RTSP_SOURCE_PORT} = $rtsp_source_port;
	return;
}

sub on_request_hook {
	my ($self, $len, $data) = @_;
	my $item;
	my $newProc;
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
#		system('taskkill /im "' . $exec_name . '"');
		my $oldProc = $self->{gui_handle}->on_receive_process_list->{$source_name};
		$oldProc->Kill(0);
		$self->AppListView->DeleteItem($find_item);
		delete($self->{gui_handle}->on_receive_process_list->{$source_name});
		return;
	}

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;

	$newProc = exec_on_receive_command($self, $source_name, $$result{COUNT});
	# Add application process.
	$self->{gui_handle}->on_receive_process_list->{$source_name} = $newProc;
	my $date = sprintf("%04d/%02d/%02d %02d:%02d:%02d" ,$year,$mon,$mday,$hour,$min,$sec);
	my $ret = $self->AppListView->InsertItem(-text => [$source_name, $$result{HOST}, $date, $newProc->GetProcessID(), $$result{COUNT}]);
	return;
}

sub ErrorReport {
	print Win32::FormatMessage(Win32::GetLastError());
	return;
}

sub exec_on_receive_command {
	my ($self, $source_name, $source_count) = @_;
	my $on_recv_cmd;
	my $newProc;
	$on_recv_cmd = $self->{gui_handle}->request_replace_code_callback->(
					$self->{gui_handle}->config_data->{ON_RECEIVE_COMMAND},
					$source_name,
					$self->{gui_handle}->config_data->{RTSP_CLIENT_PORT},
					date_time_string(),
					$source_count
		);
	my ($exec_file, $args) = split(/ /, $on_recv_cmd, 2);
	Win32::Process::Create($newProc, $exec_file, " " . $args, 0, CREATE_NO_WINDOW, ".") || die ErrorReport();
	return $newProc;
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
