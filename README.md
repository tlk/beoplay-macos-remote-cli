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
$ beoplay-cli emulator
emulating device "EmulatedDevice" on port 8080  (stop with ctrl+c)
^C
$
```

## Configuration
The command line utility is using [Bonjour](https://en.wikipedia.org/wiki/Bonjour_(software)) to discover available speakers on the local network and automatically connects to the first one found.

This default behaviour can be overriden:
```
$ beoplay-cli discover
name: Beoplay M5 i køkkenet
host: Beoplay-M5-28096178.local.
port: 8080
$ defaults write beoplay-cli host Beoplay-M5-28096178.local.
```

## Credits & Related Projects
- https://github.com/martonborzak/ha-beoplay
- https://github.com/postlund/pyatv
- https://github.com/jstasiak/python-zeroconf
- https://github.com/andybest/linenoise-swift
- https://github.com/tlk/beoplay-macos-remote-gui
