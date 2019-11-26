import Foundation
import RemoteCore

let tool = CommandLineTool()

 if let name = ProcessInfo.processInfo.environment["BEOPLAY_NAME"]{
    tool.selectDevice(name)
} else if let host = ProcessInfo.processInfo.environment["BEOPLAY_HOST"] {
    var port: Int?
    if let strPort = ProcessInfo.processInfo.environment["BEOPLAY_PORT"] {
        port = Int(strPort)
    }
    tool.setEndpoint(host: host, port: port ?? 8080)
}

var args = CommandLine.arguments;
if (args.indices.contains(1)) {
    args.removeFirst(1)
    tool.run(arguments: args)
} else {
    let interactive = Interactive(tool)
    interactive.run()
}