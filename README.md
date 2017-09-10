RTSP-Server
===========
This module is designed to accept a number of sources to connect and
transmit audio and video streams.  
Clients can connect and send RTSP commands to receive RTP data.

This was designed to make rebroadcasting audio and video data over a
network simple.

This server was extended as below function (2017/09).

- User Interface
 The source stream connection status and setting parameters are able to check via Windows GUI or WEB browser.

- Source User Authentication
 In RTSP source stream, digest authentication has been implemented.

- TCP Interleaved at Source Stream
 In RTSP source stream, the TCP interleaved mode has been implemented.

- External Command Call by Event
 On duble click(Windows only) and on receive source stream, this server execute other command line program(ffmpeg etc.).

![RTSP Server Model](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-model.png?raw=true)

# RUNNING

## Interface for Windows GUI Version (Windows only)

`perl rtsp-server-gui.pl`

![RTSP Server Windows GUI Main View](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-gui_0000.jpg?raw=true)

## Interface for WEB Interface Version (Windows, Linux and etc....)

`perl rtsp-server-web.pl`


The server status and setting interface access via browser.

`http://127.0.0.1:8090`

The initial account information is shown below.

ID is `admin` and Password is `admin`.

![RTSP Server WEB Interface Status View](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-web_0000.jpg?raw=true)

## Source Stream Client

Simply fire up the included rtsp-server.pl application and it will
listen for clients on port 554 (standard RTSP port), and source
streams on port 5545.

To begin sending video, you can use any client which supports the
ANNOUNCE and RECORD RTSP methods, such as [FFmpeg](https://www.ffmpeg.org/ffmpeg-protocols.html#rtsp):

`ffmpeg -re -i /input.avi -f rtsp -muxdelay 0.1 rtsp://12.34.56.78:5545/abc`

You should then be able to play that stream with any decent media
player. Just point it at rtsp://12.34.56.78/abc

## Execute Command Line

Windows GUI Command Line Execute Setting

![Setting View Windows GUI](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-gui_0002.jpg?raw=true)

Browser Interface Command Line Execute Setting

![Setting View Browser Interface](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-web_0002.jpg?raw=true)

| Replace Code       | Description                                               | Example Value       |
|:-------------------|:----------------------------------------------------------|:--------------------|
| <%SourceName%>     | Replace to application or source name                     | live                |
| <%RTSPClientPort%> | Replace to client side RTSP request port                  | 5545                |
| <%DateTime%>       | Replace to date Time information string as yyyymmddHHMMSS | 2017:08:01 09:00:00 |
| <%SourceCount%>    | Replace to accumulation souce connection count            | 8                   |
| <%AppPath%>        | Replace to replace to execute perl script directory       | C:\rtsp-server      |

### Examples (For Windows)

#### Recording on your hard disk 

`<%AppPath%>\cores\ffmpeg\bin\ffmpeg.exe -loglevel quiet -i rtsp://127.0.0.1:<%RTSPClientPort%>/<%SourceName%> -vcodec copy -acodec copy <%AppPath%>\record_files\<%SourceName%>_<%DateTime%>.ts`

Replace as Example

`C:\rtsp-server\cores\ffmpeg\bin\ffmpeg.exe -loglevel quiet -i rtsp://127.0.0.1:5545/live -vcodec copy -acodec copy C:\rtsp-server\record_files\live_20170801090000.ts`

Do not use mp4 format. The format needs finalize atom table process. The process dosen't make it in time.

#### Playing on your display 

`<%AppPath%>\cores\ffmpeg\bin\ffplay.exe rtsp://127.0.0.1:<%RTSPClientPort%>/<%SourceName%>`

Replace as Example

`C:\rtsp-server\cores\ffmpeg\bin\ffplay.exe rtsp://127.0.0.1:5545/live`

#### Create HTTP Live Streaming

`<%AppPath%>\cores\ffmpeg\bin\ffmpeg.exe -loglevel quiet -i rtsp://127.0.0.1:<%RTSPClientPort%>/<%SourceName%> -vcodec copy -acodec copy -f segment -segment_format mpegts -segment_time 30 -segment_list C:\inetpub\wwwroot\<%SourceName%>.m3u8 C:\inetpub\wwwroot\<%SourceName%>_<%DateTime%>_%04d.ts`

Replace as Example

`C:\rtsp-verver\cores\ffmpeg\bin\ffmpeg.exe -loglevel quiet -i rtsp://127.0.0.1:5545/live -vcodec copy -acodec copy -f segment -segment_format mpegts -segment_time 30 -segment_list C:\inetpub\wwwroot\live.m3u8 C:\inetpub\wwwroot\live_20170801090000_%04d.ts`

#### Upload to Youtube Live

`<%AppPath%>\cores\ffmpeg\bin\ffmpeg.exe -i rtsp://127.0.0.1:<%RTSPClientPort%>/<%SourceName%> -f lavfi -i anullsrc=r=44100:cl=stereo -c:a aac -b:a 128k -c:a 2 -f flv rtmp://a.rtmp.youtube.com/live2/xxxx-xxxx-xxxx-xxxx` 

Replace as Example

`C:\rtsp-verver\cores\ffmpeg\bin\ffmpeg.exe -i rtsp://127.0.0.1:5545/live -f lavfi -i anullsrc=r=44100:cl=stereo -c:a aac -b:a 128k -c:a 2 -f flv rtmp://a.rtmp.youtube.com/live2/xxxx-xxxx-xxxx-xxxx` 

For any upload Youtube live stream, the source name(<%SourceName%>) will be match to Youtube stream key.

| Replace Code       | Example Value          |
|:-------------------|:-----------------------|
| <%SourceName%>     | xxxx-xxxx-xxxx-xxxx    |


`<%AppPath%>\cores\ffmpeg\bin\ffmpeg.exe -i rtsp://127.0.0.1:<%RTSPClientPort%>/<%SourceName%> -f lavfi -i anullsrc=r=44100:cl=stereo -c:a aac -b:a 128k -c:a 2 -f flv rtmp://a.rtmp.youtube.com/live2/<%SoureName%>` 

# TODO:

Priv dropping, authentication, client encoder, stats, tests

# DEPENDENCIES

This module requires these other modules and libraries:

  Moose, AnyEvent::Socket, AnyEvent::Handle

# COPYRIGHT AND LICENCE

Copyright (C) 2014 by Mischa Spiegelmock

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


