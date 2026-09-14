import Foundation

// Development-only frontend for the exact release parser. No raw log output.
@main
struct GameLogProbe {
    static func main() throws {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--command",
           let command = GameLogObservation.command(package: CommandLine.arguments[2]) {
            print(command)
            return
        }
        guard CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--decode" else {
            fputs("Usage: tft-game-log-probe --command PACKAGE | --decode < snapshot\n", stderr)
            exit(2)
        }
        var data = Data()
        while data.count <= GameLogObservation.maximumResponseBytes,
              let chunk = try FileHandle.standardInput.read(upToCount: min(8192, GameLogObservation.maximumResponseBytes + 1 - data.count)), !chunk.isEmpty {
            data.append(chunk)
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let sanitized = try encoder.encode(GameLogObservation.decode(data))
        print(String(decoding: sanitized, as: UTF8.self))
    }
}
