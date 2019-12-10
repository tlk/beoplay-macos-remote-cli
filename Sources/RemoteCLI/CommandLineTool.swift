import Foundation
import RemoteCore
import Emulator

public class CommandLineTool {
    let defaultTimeout = 3.0
    let remoteControl = RemoteControl()
    let sema = DispatchSemaphore(value: 0)

    private func block() {
        sema.wait()
    }

    private func unblock() {
        sema.signal();
    }

    public let commands = [
        "discover",
        "selectDevice ",
        "getSources",
        "getEnabledSources",
        "setSource ",
        "tuneIn ",
        "join",
        "leave",
        "play",
        "pause",
        "stop",
        "next",
        "back",
        "getVolume",
        "setVolume ",
        "adjustVolume ",
        "mute",
        "unmute",
        "monitor ",
        "emulator ",
        "help",
    ]

    public let commandsWithoutEndpoint = [
        "discover",
        "selectDevice",
        "emulator"
    ]

    public func endpointIsRequired(_ command: String?) -> Bool {
        command != nil && 
            commands.map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !commandsWithoutEndpoint.contains($0) }
                    .contains(command!)
    }

    public func setEndpoint(host: String, port: Int) {
        print("device endpoint set to http://\(host):\(port)")
        remoteControl.setEndpoint(host: host, port: port)
    }

    public func selectDevice(_ name: String) {
        var found = false

        func handler(device: NetService) {
            guard found == false else {
                return
            }

            if device.name == name {
                found = true
                remoteControl.setEndpoint(host: device.hostName!, port: device.port)
                remoteControl.stopDiscovery()
            }
        }

        let delegate = SerializedDeviceLocator(didFind: handler, didStop: unblock)
        remoteControl.startDiscovery(delegate: delegate, withTimeout: defaultTimeout)
        block()
    }

    func sourcesHandler(sources: [BeoplaySource]) {
        if sources.isEmpty {
            fputs("failed to get sources\n", stderr)
        } else {
            dump(sources)
        }
        unblock()
    }

    private func volumeHandlerUnblock(volume: Int?) {
        volumeHandler(volume: volume)
        unblock()
    }

    private func volumeHandler(volume: Int?) {
        if volume == nil {
            fputs("failed to get volume level\n", stderr)
        } else {
            print(volume!)
        }
    }

    public func run(_ command: String?, _ option: String?) -> Int32 {
        guard self.remoteControl.hasEndpoint() || !endpointIsRequired(command) else {
            fputs("failed to configure device endpoint\n", stderr)
            return 1
        }

        switch command {
        case "discover":
            if option == "notimeout" {
                self.remoteControl.startDiscovery(delegate: ConsoleDeviceLocator())
                _ = readLine()
                self.remoteControl.stopDiscovery()                    
            } else {
                self.remoteControl.startDiscovery(delegate: ConsoleDeviceLocator(), withTimeout: defaultTimeout, next: unblock)
                block()
            }
        case "selectDevice":
            if option != nil {
                selectDevice(option!)
                if self.remoteControl.hasEndpoint() {
                    print("device endpoint successfully located")
                } else {
                    fputs("failed to locate device\n", stderr)
                    return 1
                }
            } else {
                fputs("  example:  selectDevice \"Beoplay M5\"\n", stderr)
                return 1
            }
        case "getSources":
            self.remoteControl.getSources(sourcesHandler)
            block()
        case "getEnabledSources":
            self.remoteControl.getEnabledSources(sourcesHandler)
            block()
        case "setSource":
            if let _ = option?.range(of: #"^\w+:.+"#, options: .regularExpression) {
                self.remoteControl.setSource(id: option!, unblock)
                block()
            } else {
                fputs("  example:  setSource spotify:2714.1200304.28096178@products.bang-olufsen.com\n", stderr)
                return 1
            }
        case "join":
            self.remoteControl.join(unblock)
            block()
        case "leave":
            self.remoteControl.leave(unblock)
            block()
        case "play":
            self.remoteControl.play(unblock)
            block()
        case "pause":
            self.remoteControl.pause(unblock)
            block()
        case "stop":
            self.remoteControl.stop(unblock)
            block()
        case "next":
            self.remoteControl.next(unblock)
            block()
        case "back":
            self.remoteControl.back(unblock)
            block()
        case "getVolume":
            self.remoteControl.getVolume(volumeHandlerUnblock)
            block()
        case "setVolume":
            if let opt = option, let vol = Int(opt) {
                self.remoteControl.setVolume(volume: vol, unblock)
                block()
            } else {
                fputs("  example:  setVolume 20\n", stderr)
                return 1
            }
        case "adjustVolume":
            if let opt = option, let delta = Int(opt) {
                self.remoteControl.adjustVolume(delta: delta, unblock)
                block()
            } else {
                fputs("  example:  adjustVolume -5\n", stderr)
                return 1
            }
        case "mute":
            self.remoteControl.mute(unblock)
            block()
        case "unmute":
            self.remoteControl.unmute(unblock)
            block()
        case "monitor":
            let map = [
                "connection" : Notification.Name.onConnectionChange,
                "volume": Notification.Name.onVolumeChange,
                "progress": Notification.Name.onProgress,
                "source": Notification.Name.onSourceChange,
                "radio": Notification.Name.onNowPlayingRadio,
                "storedmusic": Notification.Name.onNowPlayingStoredMusic
            ]

            var notificationNames = [Notification.Name]()
            if let opts = option?.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",") {
                notificationNames = opts.compactMap { map[String($0)] }
            } else if option != nil, let opt = map[option!] {
                notificationNames.append(opt)
            } else {
                // default to all
                notificationNames = Array(map.values)
            }

            if notificationNames.isEmpty {
                fputs("  example:  monitor connection,volume,progress,source,radio,storedmusic\n", stderr)
                return 1
            }

            var observers = [NSObjectProtocol]()
            for notificationName in notificationNames {
                let observer = NotificationCenter.default.addObserver(forName: notificationName, object: nil, queue: nil) { (notification: Notification) -> Void in
                    if let data = notification.userInfo?["data"] {
                        print("\(data as AnyObject)")
                    }
                }
                observers.append(observer)
            }
            self.remoteControl.startNotifications()

            _ = readLine()

            self.remoteControl.stopNotifications()
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        case "tuneIn":
            func map(_ input: String?) -> (String,String)? {
                input?.range(of: #"^s[0-9]+$"#, options: .regularExpression) != nil
                    ? (input!,input!)
                    : nil
            }
            var stations = [(String,String)]()
            if let matches = option?.contains(","), matches == true {
                let result = option?.split(separator: ",").compactMap {
                    id in map(String(id))
                }
                if result != nil {
                    stations = result!
                }
            } else if let station = map(option) {
                stations.append(station)
            }

            if stations.isEmpty == false {
                self.remoteControl.tuneIn(stations: stations, unblock)
                block()
            } else {
                fputs("  example:  tuneIn s24861,s37309,s69060,s45455,s69056\n", stderr)
                return 1
            }
        case "emulator":
            let name = option ?? "Beoplay Emulated Device"
            var port = 80
            if let strPort = ProcessInfo.processInfo.environment["BEOPLAY_PORT"], let p = Int(strPort) {
                port = p
            }
            print("emulating device \"\(name)\" on port \(port)  (stop with ctrl+c)")
            let emulator = DeviceEmulator()
            emulator.run(port: port, name: name)
        default:
            let pretty = commands.map { cmd in
                cmd.last == " "
                    ? "\(cmd)[option]"
                    : cmd
            }
            fputs("  available commands: \(pretty)\n", stderr)
            return 1
        }

        return 0
    }
}
