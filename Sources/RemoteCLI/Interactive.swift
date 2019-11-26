import Darwin
import LineNoise
import RemoteCore

public class Interactive {
    let ln: LineNoise
    let tool: CommandLineTool

    public init(_ tool: CommandLineTool) {
        self.tool = tool
        self.ln = LineNoise()
        setupLineNoise()
    }

    private func setupLineNoise() {
        self.ln.setCompletionCallback { currentBuffer in
            let completions = self.tool.commands
            return completions.filter { $0.hasPrefix(currentBuffer) }
        }

        self.ln.setHintsCallback { currentBuffer in
            let hints = self.tool.commands
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

    }

    public func run() {
        var done = false
        while !done {
            do {
                let input = try self.ln.getLine(prompt: "> ")
                print("")

                if input == "exit" || input == "quit" || input == "" {
                    break
                }

                // support no more than two arguments
                let args: [String] = input
                    .split(separator: " ", maxSplits: 1)
                    .map {
                        // support arguments ala:  selectDevice "Beoplay M5"
                        let str = $0.trimmingCharacters(in: .whitespaces)
                        if str.first == "\u{22}" && str.first == str.last  {
                            return String(str.dropFirst(1).dropLast(1))
                        } else {
                            return str
                        }
                    }
                self.tool.run(arguments: args)
                self.ln.addHistory(input)

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
}
