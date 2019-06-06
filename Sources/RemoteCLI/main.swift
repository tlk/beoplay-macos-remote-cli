import RemoteCore

let tool = CommandLineTool()

var args = CommandLine.arguments;
if (args.indices.contains(1)) {
    args.removeFirst(1)
    tool.run(arguments: args)
} else {
    let interactive = Interactive(tool)
    interactive.run()
}