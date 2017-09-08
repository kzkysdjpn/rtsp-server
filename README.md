RTSP-Server
===========
This module is designed to accept a number of sources to connect and
transmit audio and video streams.  
Clients can connect and send RTSP commands to receive RTP data.

This was designed to make rebroadcasting audio and video data over a
network simple.

## INSTALLATION
To install this module type the following:
```
   perl Makefile.PL
   make
   make test
   make install
```
To install debian jessie dependences:
```
   sudo apt-get install libmoose-perl liburi-perl libmoosex-getopt-perl libsocket6-perl libanyevent-perl
   sudo cpan AnyEvent::MPRPC::Client

Clone from git
   git clone https://github.com/revmischa/rtsp-server

Then make, test and install
   perl Makefile.PL
   make
   make test
   make install

```

## RUNNING

Simply fire up the included rtsp-server.pl application and it will
listen for clients on port 554 (standard RTSP port), and source
streams on port 5545.

To begin sending video, you can use any client which supports the
ANNOUNCE and RECORD RTSP methods, such as [FFmpeg](https://www.ffmpeg.org/ffmpeg-protocols.html#rtsp):

`ffmpeg -re -i /input.avi -f rtsp -muxdelay 0.1 rtsp://12.34.56.78:5545/abc`

You should then be able to play that stream with any decent media
player. Just point it at rtsp://12.34.56.78/abc

If you don't want to run it as root, you may specify non-priviliged
ports with `--clientport/-c` and `--sourceport/-s`

### On Receive Execute Command
| Replace Code       | Description                                               | Example Value          |
|:-------------------|:----------------------------------------------------------|:-----------------------|
| <%SourceName%>     | Replace to application or source name                     | live                   |
| <%RTSPClientPort%> | Replace to client side RTSP request port                  | 5545                   |
| <%DateTime%>       | Replace to date Time information string as yyyymmddHHMMSS | 2017:08:01 09:00:00    |
| <%SourceCount%>    | Replace to accumulation souce connection count            | 8                      |
| <%AppPath%>        | Replace to replace to execute perl script directory       | C:\rtsp-server         |

#### Examples

##### Create HTTP Live Streaming

`<%AppPath%>\cores\ffmpeg\bin\ffmpeg.exe -loglevel quiet -i rtsp://127.0.0.1:<%RTSPClientPort%>/<%SourceName%> -vcodec copy -acodec copy -f segment -segment_format mpegts -segment_time 30 -segment_list C:\inetpub\wwwroot\<%SourceName%>.m3u8 C:\inetpub\wwwroot\<%SourceName%>_<%DateTime%>_%04d.ts`

Replace as

`C:\rtsp-verver\cores\ffmpeg\bin\ffmpeg.exe -loglevel quiet -i rtsp://127.0.0.1:5545/live -vcodec copy -acodec copy -f segment -segment_format mpegts -segment_time 30 -segment_list C:\inetpub\wwwroot\live.m3u8 C:\inetpub\wwwroot\live_20170801090000_%04d.ts`

## TODO:

Priv dropping, authentication, client encoder, stats, tests

## DEPENDENCIES

This module requires these other modules and libraries:

  Moose, AnyEvent::Socket, AnyEvent::Handle

## COPYRIGHT AND LICENCE

Copyright (C) 2014 by Mischa Spiegelmock

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


