#!/usr/bin/env perl

use strict;
use warnings;
use lib 'lib';

use AnyEvent;
use RTSP::Server;

use RTSP::GUI;

# you may pass your own options in here or via command-line
my $srv = RTSP::Server->new_with_options(
);
$srv->add_source_update_callback(\&add_source_update_callback);

$srv->remove_source_update_callback(\&remove_source_update_callback);

# listen and accept incoming connections
$srv->listen;

# main loop
my $cv = AnyEvent->condvar;

my $gui = RTSP::GUI->new;
$gui->close_event(\&close_event);
$gui->open;

# end if interrupt
$SIG{INT} = sub {
    $cv->send;
};

$cv->recv;

sub close_event {
	$cv->send;
	return;
}

sub add_source_update_callback{
	print("Add source operation\n");
	$gui->clear_mount_element;
	foreach my $path(keys %{$srv->mounts}){
		$gui->add_mount_element(substr($path, 1));
		print substr($path, 1) . "\n";
    	}
	print("\n");
	return;
}

sub remove_source_update_callback{
	print("Remove source operation\n");
	$gui->clear_mount_element;
	foreach my $path(keys %{$srv->mounts}){
		$gui->add_mount_element(substr($path, 1));
		print substr($path, 1) . "\n";
	}
	print("\n");
	return;
}
