package Interface::ConfigFile;

use Moose;
use JSON;
use Encode;

has 'config_file_path' => (
	is => 'rw',
	default => 'C:\\perl_test\\rtsp-server\\rtsp-server.json',
);

has 'key_name' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has 'config_data' => (
	is => 'rw',
	isa => 'HashRef',
	default => sub { {} },
);

sub open {
	my ($self) = @_;
	my $fh;
	unless (open ($fh, '<', $self->config_file_path)){
		print STDERR ("Invalid open peration.\n");
		return 0;
	}
	my $data;
	eval {
		local $/ = undef;
		my $json = <$fh>;
		close $fh;
		my $tmp = Encode::encode('utf8', decode('sjis', $json));
		$DB::single=1;
		$data = decode_json($tmp);
	};
	if($@){
		$DB::single=1;
		print STDERR ("Invalid JSON decode peration.\n");
		return 0;
	}
	$self->config_data($data);
	return 1;
}

sub close {
	my ($self) = @_;
	return;
}

sub set_key_name {
	my ($self, $key_name) = @_;
	$self->key_name($key_name);
	return;
}

sub setting_value {
	my ($self) = @_;
	return $self->config_data->{$self->key_name};
}

sub set_setting_value {
	my ($self, $value) = @_;
	$self->config_data->{$self->key_name} = $value;
	return;
}

sub config_data_hash {
	my ($self) = @_;
	return $self->config_data;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME
