import Foundation
import RemoteCore

let tool = CommandLineTool()

func setupEndpoint() {
    if let name = ProcessInfo.processInfo.environment["BEOPLAY_NAME"]{
        tool.selectDevice(name)
    } else if let host = ProcessInfo.processInfo.environment["BEOPLAY_HOST"] {
        var port: Int?
        if let strPort = ProcessInfo.processInfo.environment["BEOPLAY_PORT"] {
            port = Int(strPort)
        }
        tool.setEndpoint(host: host, port: port ?? 8080)
    }
}

var args = CommandLine.arguments;
if (args.indices.contains(1)) {
    args.removeFirst(1)
    let command: String? = args.indices.contains(0) ? args[0] : nil
    let option: String? = args.indices.contains(1) ? args[1] : nil

    if tool.endpointIsRequired(command) {
        setupEndpoint()
    }

    let code = tool.run(command, option)
    exit(code)

} else {
    setupEndpoint()
    let interactive = Interactive(tool)
    interactive.run()
}