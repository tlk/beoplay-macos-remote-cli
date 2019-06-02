import Foundation
import Darwin

public final class CommandLineTool {
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

    public func run(arguments: [String]) throws {
        func volumeHandler(volume: Int) {
            print(volume)
        }

        func connectionHandler(state: RemoteNotificationsSession.ConnectionState) {
            fputs("connection state: \(state)\n", stderr)
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
                try remoteControl.play()
            case "pause":
                try remoteControl.pause()
            case "stop":
                try remoteControl.stop()
            case "forward":
                try remoteControl.forward()
            case "backward":
                try remoteControl.backward()
            case "getVolume":
                try remoteControl.getVolume(callback: volumeHandler)
            case "setVolume":
                if opt == nil {
                    fputs("  example:  setVolume 20\n", stderr)
                } else {
                    try remoteControl.setVolume(volume: opt!)
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