# beoplay-cli

This is an unofficial Command Line Interface for macOS to remote control network enabled Beoplay loudspeakers.

The CLI is built on top of the [RemoteCore](https://github.com/tlk/beoplay-macos-remote-cli/tree/master/Sources/RemoteCore) library which is also used by the [Beoplay Remote](https://github.com/tlk/beoplay-macos-remote-gui) menu bar app for macOS.

## Installation

```
$ make install
swift build -c release
[5/5] Linking ./.build/x86_64-apple-macosx/release/beoplay-cli
cp .build/release/beoplay-cli /usr/local/bin/beoplay-cli
$ 
```

## Usage

#### Interactive mode with hints and tab-completion
![screen recording](./tty.gif)

#### Non-interactive mode
```
$ beoplay-cli discover
+ "Beoplay Emulated Device"	http://macbook12.local.:80

$ export BEOPLAY_NAME="Beoplay Emulated Device"
$ beoplay-cli getVolume
35
$ beoplay-cli setVolume 20
$ beoplay-cli getVolume
20
$ beoplay-cli pause
$ beoplay-cli play
$ beoplay-cli receiveVolumeNotifications
connection state: connecting
connection state: online
20
25
28
30

connection state: disconnecting
connection state: offline
$ 
$ beoplay-cli emulator "Beoplay Emulated Device"
emulating device "Beoplay Emulated Device" on port 80  (stop with ctrl+c)
^C
$
```

## Configuration
Note that `beoplay-cli discover` is used to list Beoplay device names on the local network.

A device name must be passed to beoplay-cli for regular operations such as play, pause, etc to work. This is be done vith the selectDevice command in interactive mode and via an environment variable in non-interactive mode.

Device host and port are located automatically via [Bonjour](https://en.wikipedia.org/wiki/Bonjour_(software)).

```
$ BEOPLAY_NAME="Beoplay Emulated Device" beoplay-cli play
```

Host and port can be configured via environment variables as an alternative to Bonjour:
```
$ BEOPLAY_HOST=macbook12.local. BEOPLAY_PORT=8080 beoplay-cli getSources
```


## Credits & Related Projects
- https://github.com/martonborzak/ha-beoplay
- https://github.com/postlund/pyatv
- https://github.com/jstasiak/python-zeroconf
- https://github.com/andybest/linenoise-swift
- https://github.com/tlk/beoplay-macos-remote-gui
