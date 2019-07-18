# beoplay-cli

This is an unofficial command line utility for Mac OS to remote control network enabled Beoplay loudspeakers.

## Installation

```
$ make install
swift build -c release
[5/5] Linking ./.build/x86_64-apple-macosx/release/beoplay-cli
cp .build/release/beoplay-cli /usr/local/bin/beoplay-cli
$ 
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
available commands: ["discover", "play", "pause", "stop", "forward", "backward", "getVolume", "setVolume ", "receiveVolumeNotifications", "tuneIn ", "help", "?"]
> discover
name: Beoplay M5 i køkkenet
host: Beoplay-M5-28096178.local.
port: 8080
> 
```

## Configuration
The command line utility is using [Bonjour](https://en.wikipedia.org/wiki/Bonjour_(software)) to discover available speakers on the local network and automatically connects to the first one found.

This default behaviour can be overriden:
```
$ defaults write beoplay-cli host Beoplay-M5-28096178.local.
```

## Credits & Related Projects
- https://github.com/martonborzak/ha-beoplay
- https://github.com/postlund/pyatv
- https://github.com/jstasiak/python-zeroconf
- https://github.com/andybest/linenoise-swift
- https://github.com/tlk/beoplay-macos-remote-gui
