import Foundation
import RemoteCore
import Emulator

public class CommandLineTool {
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
        "getSources",
        "getEnabledSources",
        "setSource ",
        "play",
        "pause",
        "stop",
        "forward",
        "backward",
        "getVolume",
        "setVolume ",
        "receiveVolumeNotifications",
        "tuneIn ",
        "emulator ",
        "help",
        "?",
    ]

    public init() {
        var host: String? = UserDefaults.standard.string(forKey: "host")
        var port: Int = UserDefaults.standard.integer(forKey: "port")
        var debug = false

        func connect(host: String, port: Int) {
            if debug {
                print("connecting to http://\(host):\(port)")
            }
            self.remoteControl.setEndpoint(host: host, port: port)
        }

        if let envHost = ProcessInfo.processInfo.environment["BEOPLAY_HOST"] {
            host = envHost
            debug = true
        }

        if let envPort = ProcessInfo.processInfo.environment["BEOPLAY_PORT"] {
            port = Int(envPort)!
            debug = true
        }

        if host != nil {
            port = port > 0 ? port : 8080
            connect(host: host!, port: port)
        } else {
            // Pick the first speakers found
            var first = true
            self.remoteControl.discover({}, callback: { service in 
                if first {
                    first = false
                    connect(host: service.hostName!, port: service.port)
                    self.unblock()
                }
            })

            block()
        }
    }

    public func run(arguments: [String]) {

        func foundSpeakers(_ service: NetService) {
            print("name:", service.name)
            print("host:", service.hostName!)
            print("port:", service.port)
        }

        func sourcesHandler(sources: [BeoplaySource]) {
            if sources.isEmpty {
                fputs("failed to get sources\n", stderr)
            } else {
                dump(sources)
            }
            unblock()
        }

        func volumeHandlerUnblock(volume: Int?) {
            volumeHandler(volume: volume)
            unblock()
        }

        func volumeHandler(volume: Int?) {
            if volume == nil {
                fputs("failed to get volume level\n", stderr)
            } else {
                print(volume!)
            }
        }

        func connectionHandler(state: RemoteNotificationsSession.ConnectionState, message: String?) {
            if message == nil {
                fputs("connection state: \(state)\n", stderr)
            } else {
                fputs("connection state: \(state): \(message!)\n", stderr)
            }
        }

        if (arguments.indices.contains(0)) {
            let cmd = arguments[0]

            switch cmd {
            case "discover":
                self.remoteControl.discover(unblock, callback: foundSpeakers)
                block()
            case "getSources":
                self.remoteControl.getSources(sourcesHandler)
                block()
            case "getEnabledSources":
                self.remoteControl.getEnabledSources(sourcesHandler)
                block()
            case "setSource":
                var opt: String? = nil
                if arguments.indices.contains(1) && arguments[1].range(of: #"^\w+:.+"#, options: .regularExpression) != nil {
                    opt = arguments[1]
                }

                if opt == nil {
                    fputs("  example:  setSource spotify:2714.1200304.28096178@products.bang-olufsen.com\n", stderr)
                } else {
                    self.remoteControl.setSource(id: opt!, unblock)
                    block()
                }
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
                let opt: Int? = Int(arguments[1])
                if opt == nil {
                    fputs("  example:  setVolume 20\n", stderr)
                } else {
                    self.remoteControl.setVolume(volume: opt!, unblock)
                    block()
                }
            case "receiveVolumeNotifications":
                self.remoteControl.receiveVolumeNotifications(volumeUpdate: volumeHandler, connectionUpdate: connectionHandler)
                _ = readLine()
                self.remoteControl.stopVolumeNotifications()
            case "tuneIn":
                var opt: String? = nil
                if arguments.indices.contains(1) && arguments[1].range(of: #"^s[0-9]+$"#, options: .regularExpression) != nil {
                    opt = arguments[1]
                }

                if opt == nil {
                    fputs("  example:  tuneIn s24861   (DR P3)\n", stderr)
                    fputs("                   s37309   (DR P4)\n", stderr)
                    fputs("                   s69060   (DR P5)\n", stderr)
                    fputs("                   s45455   (DR P6)\n", stderr)
                    fputs("                   s69056   (DR P7)\n", stderr)
                    fputs("                   s148845  (Radio24syv)\n", stderr)
                } else {
                    self.remoteControl.tuneIn(id: opt!, unblock)
                    block()
                }
            case "emulator":
                var port = 8080
                var name = "EmulatedDevice"

                if arguments.indices.contains(1) {
                    if let p = Int(arguments[1]) {
                        port = p > 0 ? p : port
                    } else {
                        fputs("  example:  emulator 8080 EmulatedDevice\n", stderr)
                    }
                }

                if arguments.indices.contains(2) {
                    name = arguments[2]
                }

                print("emulating device \"\(name)\" on port \(port)  (stop with ctrl+c)")
                let emulator = DeviceEmulator()
                emulator.run(port: port, name: name)

            case "help":
                fallthrough
            case "?":
                print("available commands: \(self.commands)")
            default:
                fputs("unknown argument\n", stderr)
            }

        } else {
            fputs("  example:  beoplay-cli play\n", stderr)
        }

    }
}
