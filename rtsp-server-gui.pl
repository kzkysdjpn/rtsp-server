#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use AnyEvent;
use RTSP::Server;

use Interface::GUI::Win32;
use Interface::ConfigFile;

# Condition Variable for AnyEvent parameter.
my $cv;

my $setup_config = Interface::ConfigFile->new;
unless ( $setup_config->open ){
    print STDERR ("Invalid configuration.\n");
    exit(0);
}
# signal parameter
# 0 - reboot
# 1 - terminate
my $signal = 0;

my $gui = Interface::GUI::Win32->new;

$gui->request_replace_code_callback(sub {
    my $replace_config = Interface::ConfigFile->new;
    my $ret_string = $replace_config->replace_code(
        $_[0], # Source request string
        $_[1], # Source name
        $_[2], # RTSP client port
        $_[3], # Date and time information
        $_[4]  # Source connect accumlation count
     );
    return $ret_string;
});

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

$gui->configuration_reboot_callback(sub {
    $signal	= 0;
    $cv->send;
    return;
});

$gui->window_terminate_callback(\&close_event);
$gui->config_data($setup_config->config_data);
$gui->open;

# end if interrupt
$SIG{INT} = sub {
    $cv->send;
};

my $count = 0;

# you may pass your own options in here or via command-line
my $srv = RTSP::Server->new;
$srv->client_listen_port($setup_config->config_data->{RTSP_CLIENT_PORT});
$srv->source_listen_port($setup_config->config_data->{RTSP_SOURCE_PORT});
$srv->log_level(4);

$srv->add_source_update_callback(\&add_source_update_callback);
$srv->remove_source_update_callback(\&remove_source_update_callback);
$srv->auth_info_request_callback(\&auth_info_request_callback);
$srv->use_auth_Source(1);
$srv->use_auth_Client(0);
# listen and accept incoming connections
$srv->listen;

$setup_config->close;
$setup_config = undef;

# main loop
while($signal == 0){
    $cv = AnyEvent->condvar;
    $cv->recv;
    print "signal = " . $signal . "\n";
    $cv = undef;
    if($signal != 0){
        next;
    }
    $setup_config = Interface::ConfigFile->new;
    unless ( $setup_config->open ){
    print STDERR ("Invalid configuration.\n");
        $signal = 1;
        next;
    }
    $srv->close_server;
    undef $srv;
    sleep 1;
    $srv = RTSP::Server->new;
    $srv->client_listen_port($setup_config->config_data->{RTSP_CLIENT_PORT});
    $srv->source_listen_port($setup_config->config_data->{RTSP_SOURCE_PORT});
    $srv->log_level(4);

    $srv->add_source_update_callback(\&add_source_update_callback);
    $srv->remove_source_update_callback(\&remove_source_update_callback);
    $srv->auth_info_request_callback(\&auth_info_request_callback);

    # listen and accept incoming connections
    $srv->listen;
}
$gui->close;

sub close_event {
    $signal = 1;
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

sub auth_info_request_callback {
    my ($server_name, $user_name, $mount_path, $remote_ip) = @_;
    return "ky6340";
}
