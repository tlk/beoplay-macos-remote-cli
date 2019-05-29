import RemoteCore

do {
    let tool = CommandLineTool()
    try tool.run()
} catch {
    print("An error occurred: \(error)")
}
