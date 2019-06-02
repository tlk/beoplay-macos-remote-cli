# beoplay-cli

This is an unofficial command line utility for Mac OS to remote control network enabled beoplay loudspeakers such as the Beoplay M5.

## Installation

```
$ make install
swift build -c release
[5/5] Linking ./.build/x86_64-apple-macosx/release/Remote
cp .build/release/Remote /usr/local/bin/beoplay-cli
$ 
```

## Configuration
The loudspeakers are accessible through a web interface (fx http://192.168.1.20/index.fcgi) and the command line tool needs to know this IP address. You will have to do some discovery yourself if you do not already know what this is. Tip: check your router for a list of connected devices.

When you know the IP address of the beoplay loudspeakers it must be stored in the `beoplay-cli` user preferences:

```
defaults write beoplay-cli host 192.168.1.20     # (<-- change this to the loudspeakers ip address)
```

## Usage

#### Command line arguments
```
$ beoplay-cli getVolume
35
$ beoplay-cli setVolume 30
$ beoplay-cli getVolume
30
$ beoplay-cli pause
$ beoplay-cli play
$ 
```

#### Interactive mode (with hints and tab-completion)
```
$ beoplay-cli
> getVolume
30
> setVolume 35
> getVolume
35
> 
> receiveVolumeNotifications
connection state: connecting
connection state: online
36
38
39
40

connection state: disconnecting
connection state: offline
> 
> help
available commands: ["play", "pause", "stop", "forward", "backward", "getVolume", "setVolume ", "receiveVolumeNotifications", "help", "?"]
> 
```
