import Foundation

public final class CommandLineTool {
    public let commands = [
        "play",
        "pause",
        "stop",
        "forward",
        "backward",
        "getVolume",
        "setVolume"
    ]

    public init() {}

    public func run(arguments: [String]) throws {

        if (arguments.indices.contains(0)) {

            let cmd = arguments[0]
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
                try remoteControl.getVolume()
            case "setVolume":
                let vol = Int(arguments[1])
                try remoteControl.setVolume(volume: vol!)
            default:
                print ("unknown argument")
            }

        } else {
            print ("  example usage:  Remote play")
        }

    }
}