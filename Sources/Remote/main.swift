import Darwin
import RemoteCore
import LineNoise

func interactive() {
    let ln = LineNoise()
    let tool = CommandLineTool()

    ln.setCompletionCallback { currentBuffer in
        let completions = tool.commands
        return completions.filter { $0.hasPrefix(currentBuffer) }
    }

    ln.setHintsCallback { currentBuffer in
        let hints = tool.commands
        let filtered = hints.filter { $0.hasPrefix(currentBuffer) }

        if (currentBuffer != "") {
            if let hint = filtered.first {
                // return only the missing part of the hint
                let hintText = String(hint.dropFirst(currentBuffer.count))
                let color = (127, 127, 127)
                return (hintText, color)
            }
        }

        return (nil, nil)
    }

    var done = false
    while !done {
        do {
            let input = try ln.getLine(prompt: "> ")
            print("")

            if input == "exit" || input == "quit" || input == "" {
                break
            }

            let args = input.components(separatedBy: " ")
            try tool.run(arguments: args)
            ln.addHistory(input)

        } catch LinenoiseError.EOF {
            done = true
            print("")
        } catch LinenoiseError.CTRL_C {
            done = true
            print("")
        } catch {
            fputs("\(error)\n", stderr)
        }
    }
}

do {
    var args = CommandLine.arguments;
    if (args.indices.contains(1)) {
        args.removeFirst(1)
        let tool = CommandLineTool()
        try tool.run(arguments: args)
    } else {
        interactive()
    }
} catch {
    fputs("An error occurred: \(error)\n", stderr)
}
