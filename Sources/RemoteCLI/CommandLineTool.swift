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
        "join",
        "leave",
        "play",
        "pause",
        "stop",
        "forward",
        "backward",
        "getVolume",
        "setVolume ",
        "adjustVolume ",
        "receiveVolumeNotifications",
        "tuneIn ",
        "emulator ",
        "help",
        "?",
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
        case "forward":
            self.remoteControl.forward(unblock)
            block()
        case "backward":
            self.remoteControl.backward(unblock)
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
        case "receiveVolumeNotifications":
            self.remoteControl.receiveVolumeNotifications(volumeUpdate: volumeHandler) { 
                (state: RemoteNotificationsSession.ConnectionState, message: String?) in 

                if message == nil {
                    fputs("connection state: \(state)\n", stderr)
                } else {
                    fputs("connection state: \(state): \(message!)\n", stderr)
                }
            }

            _ = readLine()
            self.remoteControl.stopVolumeNotifications()
        case "tuneIn":
            if let _ = option?.range(of: #"^s[0-9]+$"#, options: .regularExpression) {
                self.remoteControl.tuneIn(id: option!, unblock)
                block()
            } else {
                fputs("  example:  tuneIn s24861   (DR P3)\n", stderr)
                fputs("                   s37309   (DR P4)\n", stderr)
                fputs("                   s69060   (DR P5)\n", stderr)
                fputs("                   s45455   (DR P6)\n", stderr)
                fputs("                   s69056   (DR P7)\n", stderr)
                fputs("                   s148845  (Radio24syv)\n", stderr)
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
        case "help":
            fallthrough
        case "?":
            fputs("available commands: \(self.commands)", stderr)
            fallthrough
        case "":
            fputs("  example:  beoplay-cli play\n", stderr)
            return 1
        default:
            fputs("unknown argument\n", stderr)
            return 1
        }

        return 0
    }
}
