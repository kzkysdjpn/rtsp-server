#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use AnyEvent;
use RTSP::Server;

use Interface::GUI::Win32;

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
$gui->window_terminate_callback(\&close_event);
$gui->open;

# end if interrupt
$SIG{INT} = sub {
    $cv->send;
};

my $count = 0;

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
