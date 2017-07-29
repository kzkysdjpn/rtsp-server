package Interface::ConfigFile;

use Moose;
use JSON::PP;
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
	my $data;
	my $tmp;
	my $json;
	unless (CORE::open ($fh, "<", $self->config_file_path)){
		print STDERR ("Invalid CORE::open peration in ConfigFile::open().\n");
		return 0;
	}
	eval {
		local $/ = undef;
		$json = <$fh>;
		CORE::close $fh;
		$tmp = Encode::encode('utf8', decode('sjis', $json));
		$data = JSON::PP::decode_json($tmp);
	};
	if($@){
		print STDERR ("Invalid JSON decode operation." . $@ .  "\n");
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

sub write {
	my ($self) = @_;
	my $fh;
	unless ( CORE::open ($fh, ">", $self->config_file_path)){
		print STDERR "Invalid CORE::open peration in ConfigFile::write(): $!\n";
		return 0;
	}
	eval {
		local $/ = undef;
		my $json = JSON::PP::encode_json($self->config_data);
		print $fh $json;
		CORE::close $fh;
	};
	if($@){
		print STDERR "Invalid JSON encode operation." . $@ . "\n";
		return 0;
	}
	return 1;
}

use FindBin;

sub get_app_path {
	my $app_path = $FindBin::Bin;
	$app_path =~ s/(?:\/)/\\/g;
	return $app_path;
}

sub replace_code {
	my ($self, $source_string, $source_name, $rtsp_port, $date_time, $source_count) = @_;
	my $app_path = get_app_path;
	my @replace_source = (
		"<%SourceName%>",
		"<%RTSPClientPort%>",
		"<%DateTime%>",
		"<%SourceCount%>",
		"<%AppPath%>"
	);
	my @replace_string = (
		$source_name,
		$rtsp_port,
		$date_time,
		$source_count,
		$app_path
	);

	foreach my $i(0 .. $#replace_source){
		$source_string =~ s/(?:$replace_source[$i])/$replace_string[$i]/g;
	}

	return $source_string;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME
