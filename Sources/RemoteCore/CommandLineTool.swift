import Foundation

public final class CommandLineTool {
    private let arguments: [String]

    public init(arguments: [String] = CommandLine.arguments) { 
        self.arguments = arguments
    }

    public func run() throws {

        if (self.arguments.indices.contains(1)) {
            
            let cmd = self.arguments[1]
            let remote = RemoteControl()

            switch cmd {
            case "play":
                try remote.play()
            case "pause":
                try remote.pause()
            case "stop":
                try remote.stop()
            case "forward":
                try remote.forward()
            case "backward":
                try remote.backward()
            default:
                print ("unknown argument")
            }

        } else {
            print ("  example usage:  Remote play")
        }
        
    }
}