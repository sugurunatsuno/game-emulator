import Foundation

@main
enum InstallerIntegration {
    static func main() throws {
        guard CommandLine.arguments.count == 6 else {
            throw IntegrationFailure("usage: InstallerIntegration ROOT RESOURCES PLATFORM_ZIP EMULATOR_ZIP SYSTEM_ZIP")
        }
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        let resources = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        let paths = try LauncherPaths(root: root, resources: resources)
        let manifest = try SystemServices.loadManifest(from: paths.manifest)
        try FileManager.default.createDirectory(at: paths.downloads, withIntermediateDirectories: true)

        let archives = Array(CommandLine.arguments[3 ... 5])
        for (component, archivePath) in zip(manifest.components, archives) {
            let source = URL(fileURLWithPath: archivePath)
            let target = paths.downloads.appendingPathComponent("\(component.id).zip")
            guard try SystemServices.sha256(of: source) == component.sha256 else {
                throw IntegrationFailure("fixture hash mismatch: \(source.lastPathComponent)")
            }
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: source, to: target)
        }

        var result: Result<InstallState, Error>?
        let installer = InstallerService(paths: paths, manifest: manifest)
        installer.install(repair: false, progress: { progress in
            print("[\(Int(progress.fraction * 100))%] \(progress.message)")
        }, completion: { completion in
            result = completion
        })
        while result == nil {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        let state = try result!.get()
        guard state.isRuntimeReady,
              state.games[GameEdition.global.id]?.gameBaseSHA256?.range(
                  of: "^[0-9a-f]{64}$",
                  options: .regularExpression
              ) != nil,
              FileManager.default.fileExists(atPath: paths.avdDirectory.appendingPathComponent("hardware-qemu.ini").path) else {
            throw IntegrationFailure("installer did not produce a ready AVD")
        }
        print("Mactician provisioning integration: OK")
        print("Integration root: \(root.path)")
    }
}

struct IntegrationFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
