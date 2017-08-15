package Interface::WEB::Httpd;
use Moose;

use HTTP::Daemon;
use HTTP::Date;

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
	default => sub {return "$FindBin::Bin/html/"},
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


has 'configuration_reboot_callback' => (
	is => 'rw',
	default => sub {
		sub {
			return;
		}
	},
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

has 'config_data' => (
	is => 'rw',
	default => sub {},
);

has 'httpd_obj' => (
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
	my $d = HTTP::Daemon->new(LocalAddr => $self->bind_addr, LocalPort => $self->bind_port) || die $!;
	$self->httpd_obj($d);
	$self->httpd_obj->timeout($self->accept_timeout);
	while (! $self->signal_terminate ){
		unless ( $c, $peer_addr ) = $self->httpd_obj->accept()){
			next;
		}
		while(my $req = $c->get_request ){
			my $header = HTTP::Headers->new( 'Content-Type' => 'text/plain' );
			my $res = HTTP::Response->new( 200, 'OK', $header, "Test Server" );
			$c->send_response($res);
		}
		$c->close;
	}
	return;
}
