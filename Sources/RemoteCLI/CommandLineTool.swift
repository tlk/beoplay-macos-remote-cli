import Foundation
import RemoteCore

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
        "play",
        "pause",
        "stop",
        "forward",
        "backward",
        "getVolume",
        "setVolume ",
        "receiveVolumeNotifications",
        "tuneIn ",
        "setPrimaryExperience",
        "leavePrimaryExperience",
        "help",
        "?",
    ]

    public init() {
        let host = UserDefaults.standard.string(forKey: "host")
        if host != nil {
            var port = UserDefaults.standard.integer(forKey: "port")
            port = port > 0 ? port : 8080
            self.remoteControl.setEndpoint(host: host!, port: port)
        } else {
            // Pick the first speakers found
            var first = true
            self.remoteControl.discover(unblock, callback: { service in 
                if first {
                    first = false
                    self.remoteControl.setEndpoint(host: service.hostName!, port: service.port)
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

        func volumeHandlerUnblock(volume: Int?) {
            volumeHandler(volume: volume)
            unblock()
        }

        func volumeHandler(volume: Int?) {
            if volume == nil {
                fputs("no volume level reading\n", stderr)
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
            case "getSources":
                self.remoteControl.getSources { sources in
                    let keys = Array(sources.keys)
                    for key in keys.sorted() {
                        print("source: \(key), \(sources[key]!)")
                    }
                    self.unblock()
                }
                block()
            case "tuneIn":
                var opt: String? = nil
                if arguments.indices.contains(1) && arguments[1].range(of: #"^s[0-9]+$"#, options: .regularExpression) != nil {
                    opt = arguments[1]
                }

                if opt == nil {
                    fputs("  example:  tunein s24861   (DR P3)\n", stderr)
                    fputs("                   s37309   (DR P4)\n", stderr)
                    fputs("                   s69060   (DR P5)\n", stderr)
                    fputs("                   s45455   (DR P6)\n", stderr)
                    fputs("                   s69056   (DR P7)\n", stderr)
                    fputs("                   s148845  (Radio24syv)\n", stderr)
                } else {
                    self.remoteControl.tuneIn(id: opt!, unblock)
                    block()
                }
            case "setPrimaryExperience":
                self.remoteControl.setPrimaryExperience(sourceId: arguments[1], unblock)
                block()
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
