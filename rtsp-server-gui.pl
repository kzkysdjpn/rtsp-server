#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use AnyEvent;
use RTSP::Server;

use Interface::GUI::Win32;
use Interface::ConfigFile;

my $initial_config = Interface::ConfigFile->new;
unless ( $initial_config->open ){
	print STDERR ("Invalid configuration.\n");
	exit(0);
}
# you may pass your own options in here or via command-line
my $srv = RTSP::Server->new_with_options(
);
$srv->add_source_update_callback(\&add_source_update_callback);

$srv->remove_source_update_callback(\&remove_source_update_callback);

# listen and accept incoming connections
$srv->listen;

# main loop
my $cv = AnyEvent->condvar;

my $gui = Interface::GUI::Win32->new;
$gui->config_data_fetch_callback(sub {
	my $fetch_config;
	my $config_hash;
	$fetch_config = Interface::ConfigFile->new;
	unless ( $fetch_config->open ){
		print STDERR ("Invalid open config in fetch.\n");
		return undef;
	}
	$config_hash = $fetch_config->config_data;
	return $config_hash;
});

$gui->config_data_write_callback(sub {
	my ($config_hash) = @_;
	my $write_config;
	$write_config = Interface::ConfigFile->new;
	unless ( $write_config->open){
		print STDERR ("Invalid open config in write.\n");
		return;
	}
	$write_config->config_data($config_hash);
	unless ( $write_config->write ){
		print STDERR ("Invalid write config operation.\n");
		return;
	}
	return;
});

$gui->request_replace_code_callback(sub {
	print "request replace code callback\n";
	return;
});

$gui->window_terminate_callback(\&close_event);
$gui->initial_config($initial_config->config_data);
$gui->open;

# end if interrupt
$SIG{INT} = sub {
    $cv->send;
};

my $count = 0;

$initial_config->close;
$initial_config = undef;

$cv->recv;
$gui->close;

sub close_event {
	$cv->send;
	return;
}

sub add_source_update_callback{
    my ($mount) = @_;
    $count++;
    $gui->add_application($mount, $count);
    return;
}

sub remove_source_update_callback{
    my ($path) = @_;
    $gui->remove_application($path, $count);
    return;
}
