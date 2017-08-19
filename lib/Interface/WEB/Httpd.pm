package Interface::WEB::Httpd;

use Moose;

use HTTP::Daemon;
use HTTP::Date;
use File::Basename 'fileparse';

use threads;
use Thread::Queue;
use AnyEvent::Util;
use Socket;

use Storable;
use Storable qw(nfreeze thaw);

use JSON::PP;

use UNIVERSAL::require;

has 'bind_addr' => (
	is => 'rw',
	isa => 'Str',
	default => '0.0.0.0',
);

has 'bind_port' => (
	is => 'rw',
	isa => 'Int',
	default => 8090,
);

has 'html_root_dir' => (
	is => 'rw',
	isa => 'Str',
	default => sub {
		my $rootpath = "$FindBin::Bin/html/";
		if ( $^O eq "MSWin32" ){
			$rootpath =~ s|/|\\|g;
		}
		return $rootpath;
	},
);

has 'accept_timeout' => (
	is => 'rw',
	isa => 'Int',
	default => 1,
);

has 'signal_reboot_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'signal_terminate_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
);

has 'signal_terminate' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);

has 'local_control_port' => (
	is => 'rw',
	isa => 'Int',
	default => 65432,
);

has 'local_control_socket' => (
	is => 'rw',
);

has 'watcher' => (
	is => 'rw',
	clearer => 'clear_watcher',
);

has 'httpd_thread_obj' => (
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

has 'httpd_obj' => (
	is => 'rw',
);

has 'queue_to_httpd' => (
	is => 'rw',
	isa => 'Thread::Queue',
	default => sub {return Thread::Queue->new();},
);

has 'source_table_list' => (
	is => 'rw',
	isa => 'ArrayRef',
	default => sub { [] },
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
				$self->signal_reboot_callback,
				$self->signal_terminate_callback,
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

	# Create WEB interface thread.
	my $thread = threads->new(\&open_httpd_interface, @_);
	$self->httpd_thread_obj($thread);
	return 1;
}

sub open_httpd_interface {
	my ($self) = @_;
	my $c;
	my $peer_addr;
	my @suffix_types = (
		"json",
	);
	my @content_processes = (
		\&json_contents_process,
	);
	my $length;
	my $d = HTTP::Daemon->new(LocalAddr => $self->bind_addr, LocalPort => $self->bind_port) || die $!;
	my $suffix;
	my $i;
	my $header;
	my $res;
	$self->httpd_obj($d);
	$self->httpd_obj->timeout($self->accept_timeout);
	$length = @suffix_types;
	while (! $self->signal_terminate ){
		unless (($c, $peer_addr) = $self->httpd_obj->accept()){
			$self->fetch_source_list;
			next;
		}
		while(my $req = $c->get_request ){
			my %contents = (
				'ContentType' => "text/plain",
				'Body' => "",
			);
			$suffix = $self->parse_request_path_suffix($req->url->path);
			$i = 0;
			for ($i = 0; $i < $length ; $i++){
				if($suffix eq $suffix_types[$i]){
					last;
				}
			}
			if($length <=  $i){
				%contents = $self->default_contents_process($req->url->path);
				unless( length($contents{'Body'})){
					$self->reply_not_found($c);
					next;
				}
				$header = HTTP::Headers->new( 'Content-Type' => $contents{'ContentType'} );
				$res = HTTP::Response->new( 200, 'OK', $header, $contents{'Body'});
				$c->send_response($res);
				next;
			}
			%contents = $content_processes[$i]->($self, $req->url->path);
			unless(length($contents{'Body'})){
				$self->reply_not_found($c);
				next;
			}
			$header = HTTP::Headers->new( 'Content-Type' => $contents{'ContentType'});
			$res = HTTP::Response->new( 200, 'OK', $header, $contents{'Body'});
			$c->send_response($res);
		}
		$c->close;
	}
	return;
}

sub close {
	my ($self) = @_;
	$self->httpd_thread_obj->join;
	return;
}

sub parse_request_path_suffix {
	my ($self, $path) = @_;
	my $regex_suffix = qr/\.[^\.]+$/;
	my $suffix;

	if($path eq "/" ){
		$path = "/index.html";
	}

	$suffix = "";
	$suffix = (fileparse $path, $regex_suffix)[2];
	if(length($suffix) > 1){
		$suffix = substr($suffix, 1);
	}
	return $suffix;
}

sub default_contents_process {
	my ($self, $path) = @_;
	my $body = "";
	my $filename;
	my $file_path;
	my $suffix;
	my %suffix_types = (
		"txt" => "text/plain",
		"html" => "text/html",
		"js" => "text/javascript",
		"css" => "text/css",
		"jpg" => "image/jpeg",
		"png" => "image/png",
		"bmp" => "image/bmp",
		"csv" => "text/csv",
		"tiff" => "image/tiff",
		"exe" => "application/octet-stream",
		"bin" => "application/octet-stream",
		"zip" => "application/zip",
		"lzh" => "application/x-lzh",
		"mp4" => "audio/mp4",
		"mpeg" => "video/mpeg",
		"json" => "application/json",
		"tgz" => "application/x-tar",
	);
	my %contents = (
		'ContentType' => "text/plain",
		'Body' => "",
	);
	if($path eq "/" ){
		$path = "/index.html";
	}
	$file_path = substr($path, 1);

	if ( $^O eq "MSWin32" ){
		$file_path =~ s|/|\\|g;
	}
	$filename = $self->html_root_dir . $file_path;
	my $size = -s $filename;
	CORE::open(IN_FILE, "< $filename") or return %contents;
	binmode(IN_FILE);
	read(IN_FILE, $body, $size);
	CORE::close(IN_FILE);
	$suffix = $self->parse_request_path_suffix($path);
	my $suffix_found = 0;
	foreach my $key(keys(%suffix_types)){
		unless($suffix eq $key){
			next;
		}
		$suffix_found = 1;
		$contents{'ContentType'} = $suffix_types{$key};
		last;
	}
	unless($suffix_found){
		$contents{'ContentType'} = $suffix_types{"bin"};
	}
	$contents{'Body'} = $body;
	return %contents;
}

sub json_contents_process {
	my ($self, $path) = @_;
	my $file_path;
	my %target_json_data = (
		"source_table_list.json" => \&source_table,
		"server_config.json" => \&server_config,
		"server_address_info.json" => \&server_address_info,
	);
	my %contents = (
		'ContentType' => "text/plain",
		'Body' => "",
	);
	$file_path = substr($path, 1);
	foreach my $key(keys(%target_json_data)){
		unless($file_path eq $key){
			next;
		}
		$contents{ContentType} = "application/json";
		$contents{Body} = $target_json_data{$key}->($self);
		last;
	}
	return %contents;
}

sub source_table{
	my ($self) = @_;
	my $source_table_list = $self->source_table_list;
	my $json = "";
	$json = JSON::PP::encode_json($source_table_list);
	return $json;
}

sub server_config{
	my ($self) = @_;
	my $config_hash;
	my $user_info;
	my $json = "";
	$config_hash = $self->config_data_fetch_callback->();

	$user_info = $config_hash->{SOURCE_AUTH_INFO_LIST};
	for my $href ( @$user_info ) {
		delete($$href{PASSWORD});
	}

	delete($config_hash->{HTTPD_SETTINGS}->{AUTH_INFO}->{PASSWORD});

	$json = JSON::PP::encode_json($config_hash);
	return $json;
}

sub server_address_info {
	my ($self) = @_;
	my $json = "";
	my @addrs = ();
	unless ($^O eq "MSWin32"){
		"IO::Interface::Simple"->require;
		my @ifs = IO::Interface::Simple->interfaces;
		my $i;
		foreach $i (@ifs) {
			if($i->address eq "127.0.0.1"){
				next;
			}
			push(@addrs, $i->address);
		}
	}else{
		my @all_addrs = map { s/^.*://; s/\s//; $_ } grep {/IPv4/} `ipconfig`;
		foreach my $addr (@all_addrs) {
			if($addr eq "127.0.0.1"){
				next;
			}
			chomp($addr);
			push(@addrs, $addr);
		}
	}
	my %addr_info = (
		'PORT' => $self->config_data->{RTSP_SOURCE_PORT},
		'IP' => \@addrs,
		'CLIENT_PORT' => $self->config_data->{RTSP_CLIENT_PORT},
	);
	$json = JSON::PP::encode_json(\%addr_info);

	return $json;
}

sub reply_not_found {
	my ($self, $c) = @_;
	my $header = HTTP::Headers->new( 'Content-Type' => 'text/html' );
	my $res = HTTP::Response->new( 404, 'Not Found', $header, "<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Transitional//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd\"><html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"en\" lang=\"en\"><head><meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" /><title>Not Found (404)</title><style type=\"text/css\">body { background-color: #fff; color: #666; text-align: center; font-family: arial, sans-serif; } div.dialog { width: 25em; padding: 0 4em; margin: 4em auto 0 auto; border: 1px solid #ccc; border-right-color: #999; border-bottom-color: #999; } h1 { font-size: 100%; color: #f00; line-height: 1.5em; }</style></head><body><div class=\"dialog\"><h1>Not Found.</h1></div></body></html>");
	$c->send_response($res);
	return;
}

sub fetch_source_list {
	my ($self) = @_;
	my $data;
	my $date;
	my $i;
	my $href;
	my $source_table_list = $self->source_table_list;
	my $source_name;
	$data = $self->queue_to_httpd->dequeue_nb();
	unless(defined($data) ){
		return;
	}
	$source_name = substr($$data{SOURCE_NAME}, 1);
	unless($$data{OPS}){# 0 - Remove Source
		for($i = 0; $i < scalar(@$source_table_list); $i++){
			$href = @$source_table_list[$i];
			if($$href{SOURCE_NAME} eq $source_name){
				splice(@$source_table_list, $i, 1);
			}

		}
		$self->source_table_list($source_table_list);
		return;
	}
	# 1 - Add Source
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	$date = sprintf("%04d/%02d/%02d %02d:%02d:%02d" ,$year,$mon,$mday,$hour,$min,$sec);
	$href = {
		"SOURCE_NAME" => $source_name,
		"HOST" => $$data{HOST},
		"DATE" => $date,
		"PID" => 0, 
		"COUNT" => $$data{COUNT},
	};
	push(@$source_table_list, $href);
	$self->source_table_list($source_table_list);
	return;
}

sub add_source {
	my ($self, $mount, $count) = @_;
	my $data = {
		# Arbitary Defined
		# 0 - Remove Source 
		# 1 - Add Source
		"OPS" => 1,
		"SOURCE_NAME" => $mount->path,
		"HOST" => $mount->source_host,
		"COUNT" => $count,
	};
	$self->queue_to_httpd->enqueue($data);
	return;
}

sub remove_source {
	my ($self, $path, $count) = @_;
	my $data = {
		# Arbitary Defined
		# 0 - Remove Source
		# 1 - Add Source
		"OPS" => 0,
		"SOURCE_NAME" => $path,
		"HOST" => "",
		"COUNT" => $count,
	};
	$self->queue_to_httpd->enqueue($data);
	return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME
