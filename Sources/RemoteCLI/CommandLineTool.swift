import Foundation
import RemoteCore

public class CommandLineTool {
    public let commands = [
        "play",
        "pause",
        "stop",
        "forward",
        "backward",
        "getVolume",
        "setVolume ",
        "receiveVolumeNotifications",
        "help",
        "?",
    ]

    public init() {}

    public func run(arguments: [String]) {
        let sema = DispatchSemaphore(value: 0)
        func block() {
            sema.wait()
        }

        func unblock() {
            sema.signal();
        }

        func volumeHandler(volume: Int?) {
            if volume == nil {
                fputs("no volume level reading\n", stderr)
            } else {
                print(volume!)
            }
            unblock()
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
            var opt: Int? = nil
            if arguments.indices.contains(1) {
                opt = Int(arguments[1])
            }

            let remoteControl = RemoteControl()

            switch cmd {
            case "play":
                remoteControl.play(unblock)
                block()
            case "pause":
                remoteControl.pause(unblock)
                block()
            case "stop":
                remoteControl.stop(unblock)
                block()
            case "forward":
                remoteControl.forward(unblock)
                block()
            case "backward":
                remoteControl.backward(unblock)
                block()
            case "getVolume":
                remoteControl.getVolume(volumeHandler)
                block()
            case "setVolume":
                if opt == nil {
                    fputs("  example:  setVolume 20\n", stderr)
                } else {
                    remoteControl.setVolume(volume: opt!, unblock)
                    block()
                }
            case "receiveVolumeNotifications":
                remoteControl.receiveVolumeNotifications(volumeUpdate: volumeHandler, connectionUpdate: connectionHandler)
                _ = readLine()
                remoteControl.stopVolumeNotifications()
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
