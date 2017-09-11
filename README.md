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

# Setup

## 1. Install Module

`cpan install AnyEvent`

`cpan install MooseX::Getopt`

`cpan install UNIVERSAL::require`

`cpan install Win32::GUI`

## 2. Download and Copy External Command Line Program

Download external command line program such as [FFmpeg](https://www.ffmpeg.org/).

```
HOME
+- rtsp-server
    +- cores
        +- ffmpeg
            +- bin
               |- README.txt <- Describe this directory.
               |- ffmpeg.exe <- Copy the Command Line Program
               +- ffplay.exe <- Copy the Command Line Program

```
## 3. Start Up a RTSP Server

### Interface for Windows GUI Version (For Windows only)

`perl rtsp-server-gui.pl`

![RTSP Server Windows GUI Main View](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-gui_0000.jpg?raw=true)

### Interface for WEB Interface Version (For Windows, Linux and etc....)

`perl rtsp-server-web.pl`


The server status and setting interface access via browser.

`http://127.0.0.1:8090`

The initial account information is shown below.

ID is `admin` and Password is `admin`.

![RTSP Server WEB Interface Status View](https://github.com/kzkysdjpn/readme_resource/blob/master/rtsp-server-web_0000.jpg?raw=true)

## 4. Setup Execute Command Line

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


## 4. To Connect the Stream Client

The server assigned IP and port are displayed on status screen.

Simply fire up the included rtsp-server.pl application and it will
listen for clients on port 5545 (standard RTSP port), and source
streams on port 5445.

### FFmpeg

To begin sending video, you can use any client which supports the
ANNOUNCE and RECORD RTSP methods, such as [FFmpeg](https://www.ffmpeg.org/ffmpeg-protocols.html#rtsp):

`ffmpeg -re -i /input.avi -f rtsp -muxdelay 0.1 rtsp://12.34.56.78:5445/abc`

### Live-Reporter

[Live-Reporter](http://kzkysdjpn.mydns.jp/index.html?LANG=en) is live streaming from smartphone camera.
The application supports for iOS and Android.

In addition, You should then be able to play that stream with any decent media
player. Just point it at rtsp://12.34.56.78/abc

# Directory

## Source Directroy Structure

```
HOME
+- rtsp-server
    |- rtsp-server.pl <- Base Main Module.
    |- rtsp-server-gui.pl <- Windows GUI Interface Version 2017/09 Checkined.
    |- rtsp-server-web.pl <- WEB Browser Interface Version 2017/09 Checkined.
    |- README.md
    |- html <- HTML Setting Page Document Root for WEB Browser Interface 2017/09 Checkined.
    |- rtsp-server.json <- Setting File for GUI and Browser Interface Version 2017/09 Checkined.
    |- strawberry_perl32_pp_to_gui_exe.bat <- To Windows GUI Interface, Build for Windows Execute File by PAR::Packer script. 2017/09 Checkined.
    |- strawberry_perl32_pp_to_web_exe.bat <- To WEB Browser Interface, Build for Windows Execute File by PAR::Packer script. 2017/09 Checkined.
    +- cores
        +- ffmpeg
            +- bin
               |- README.txt <- Describe this directory.
               |- ffmpeg.exe <- Copy to Your Self
               +- ffplay.exe <- Copy to Your Self
    +- record_files
        +- README.txt <- Describe this directory.

    +- lib
        +- Interface <- 2017/09 Checkined.
            |- ConfigFile.pm
            |- ExternalCall.pm
            +- GUI
                +- Win32.pm
            +- WEB
                +- Httpd.pm
        +- RTSP
            +- RTSP Server Modules etc...
```

## Windows Execute Directory Structure

```
HOME
+- rtsp-server
    |- rtsp-server-gui.exe
    |- rtsp-server-web.exe
    |- html
    |- rtsp-server.json
    +- cores
        +- ffmpeg
            +- bin
               |- README.txt
               |- ffmpeg.exe
               +- ffplay.exe
    +- record_files
        +- README.txt
    +- lib
```

# Todo:

Priv dropping, authentication, client encoder, stats, tests

# Dependencies

This module requires these other modules and libraries:

  Moose, AnyEvent::Socket, AnyEvent::Handle

# Copyright And Licence

Copyright (C) 2014 by Mischa Spiegelmock

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


