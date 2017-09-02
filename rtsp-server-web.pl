#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use AnyEvent;
use RTSP::Server;

use Interface::WEB::Httpd;
use Interface::ConfigFile;
use Interface::ExternalCall;
# Condition Variable for AnyEvent parameter.
my $cv;

my $setup_config = Interface::ConfigFile->new;
if(! $setup_config->open ){
    print STDERR "Invalid configuration.\n";
    return;
}

# signal parameter
# 0 - reboot
# 1 - terminate
my $signal = 0;

# Execute External Process
# This module initialize at first.
# In Linux, the fork system call using.
my $ext_call = Interface::ExternalCall->new;
if(!$ext_call->open){
	print STDERR "Failed to open external system execute module.\n";
	return;
}
my %process_list = ();

# WEB Interface allocate and initialize.
my $web = Interface::WEB::Httpd->new;

$web->config_data_fetch_callback(sub {
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

$web->config_data_write_callback(sub {
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

$web->signal_reboot_callback(sub {
	$signal = 0;
	$cv->send;
	return;
});

$web->signal_terminate_callback(sub {
	$signal = 1;
	$cv->send;
	return;
});

$web->config_data($setup_config->config_data);
if(!$web->open){
	print STDERR "Failed to open web interface module.\n";
	return;
}

# end if interrupt
$SIG{INT} = sub {
    $cv->send;
};

my $count = 0;

# you may pass your own options in here or via command-line
my $srv = RTSP::Server->new;
$srv->client_listen_port($setup_config->config_data->{RTSP_CLIENT_PORT});
$srv->source_listen_port($setup_config->config_data->{RTSP_SOURCE_PORT});
$srv->rtp_start_port($setup_config->config_data->{RTP_START_PORT});
$srv->log_level(0);

$srv->add_source_update_callback(\&add_source_update_callback);
$srv->remove_source_update_callback(\&remove_source_update_callback);
$srv->auth_info_request_callback(\&auth_info_request_callback);
if( $setup_config->config_data->{USE_SOURCE_AUTH} ){
    $srv->use_auth_Source(1);
}else{
    $srv->use_auth_Source(0);
}
$srv->use_auth_Client(0);
# listen and accept incoming connections
$srv->listen;

my $auth_list = $setup_config->config_data->{SOURCE_AUTH_INFO_LIST};

$setup_config->close;
$setup_config = undef;

# main loop
while($signal == 0){
    $cv = AnyEvent->condvar;
    $cv->recv;
    $srv->close_server;
    undef $srv;

    $ext_call->stop_all_process;

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
    sleep 3; # Reboot process need interval......
    $srv = RTSP::Server->new;
    $srv->client_listen_port($setup_config->config_data->{RTSP_CLIENT_PORT});
    $srv->source_listen_port($setup_config->config_data->{RTSP_SOURCE_PORT});
    $srv->rtp_start_port($setup_config->config_data->{RTP_START_PORT});
    if( $setup_config->config_data->{USE_SOURCE_AUTH} ){
        $srv->use_auth_Source(1);
    }else{
        $srv->use_auth_Source(0);
    }
    $srv->use_auth_Client(0);
    $auth_list = $setup_config->config_data->{SOURCE_AUTH_INFO_LIST};
    $srv->log_level(0);

    $srv->add_source_update_callback(\&add_source_update_callback);
    $srv->remove_source_update_callback(\&remove_source_update_callback);
    $srv->auth_info_request_callback(\&auth_info_request_callback);

    # listen and accept incoming connections
    $srv->listen;
}
$web->close;
$ext_call->close;

sub add_source_update_callback{
    my ($mount) = @_;
    my $source_name = substr($mount->path, 1);
    # Date and Time
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $count++;

    $year += 1900;
    $mon += 1;
    my $date = sprintf("%04d%02d%02d%02d%02d%02d" ,$year,$mon,$mday,$hour,$min,$sec);
    # Execute Process
    my $replace_config = Interface::ConfigFile->new;
    unless($replace_config->open){
        return;
    }
    my $ret_string = $replace_config->replace_code(
        $replace_config->config_data->{ON_RECEIVE_COMMAND}, # Source request string
        $source_name,                            # Source name
        $replace_config->config_data->{RTSP_CLIENT_PORT},   # RTSP client port
        $date,                                              # Date and time information
        $count                                              # Source connect accumlation count
    );
    # Execute External Program via command line system call.
    $ext_call->external_command_line($ret_string);
    $ext_call->start_process;
    $process_list{$source_name} = $ext_call->reply_status;

    $web->add_source(
        $mount,                      # Source Name
        $count,                      # Connection Count
        $date,                       # Connection Start Time
        $process_list{$source_name}, # Running External Process
    );
    return;
}

sub remove_source_update_callback{
    my ($path) = @_;
    my $source_name = substr($path, 1);
    $web->remove_source($path, $count);
    if(!exists($process_list{$source_name})){
        return;
    }
    $ext_call->terminate_process_id($process_list{$source_name});
    delete($process_list{$source_name});
    $ext_call->stop_process();
    return;
}

sub auth_info_request_callback {
    my ($server_name, $user_name, $mount_path, $remote_ip) = @_;
    my $password = "";
    my $mount = "";
    foreach my $href ( @$auth_list ) {
        if ( $$href{USERNAME} ne $user_name ){
            next;
        }
        $password = $$href{PASSWORD};
        $mount = $$href{MOUNT_PATH};
        last;
    }
    unless ( length($password) ){
        return $password;
    }
    unless ( length($mount) ){
        return $password;
    }
    if ( $mount ne $mount_path ){
        return "";
    }
    return $password;
}
