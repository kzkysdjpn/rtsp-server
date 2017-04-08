package Interface::ConfigFile;

use Moose;
use JSON;
use Encode;

has 'config_file_Path' => (
	is => 'rw',
	default => 'C:\\perl_test\\rtsp-server\\rtsp-server.json',
);

has 'key_name' => (
	is => 'rw',
	isa => 'Str',
	default => '',
);

has 'value' => (
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
	open ( my $fh, '<', $self->config_file_Path) || return 0;
	my $data;
	eval {
		local $/ = undef;
		my $json = <$fh>;
		close $fh;
		my $tmp = Encode::encode('utf8', decode('sjis', $json));
		$data = decode_json($tmp);
	};
	if($@){
		return 0;
	}
	$self->config_data($data);
	$DB::single=1;
	return 1;
}

sub close {
	my ($self) = @_;
	return;
}

sub setting_value {
	my ($self) = @_;
#	return $self->config_data{$self->key_name};
}

sub set_setting_value {
	my ($self, $value) = @_;
	return $self->value($value);
}