import AppKit
import SwiftUI

@main
struct MacticianApp: App {
    @StateObject private var model = EmulatorModel()

    var body: some Scene {
        WindowGroup("Android ゲームエミュレータ") {
            EmulatorView(model: model)
                .frame(minWidth: 620, minHeight: 430)
        }
        .commands { CommandGroup(replacing: .newItem) { } }
    }
}

struct EmulatorView: View {
    @ObservedObject var model: EmulatorModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Android ゲームエミュレータ")
                .font(.system(size: 28, weight: .bold))
            Text("既存のAndroid SDKとAVDを使ってゲームを起動します。")
                .foregroundStyle(.secondary)
            GroupBox("実行環境") {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Android SDKのパス", text: $model.sdkRoot)
                    TextField("AVD名", text: $model.avdName)
                    TextField("起動するパッケージ（任意）", text: $model.packageName)
                }
                .textFieldStyle(.roundedBorder)
            }
            HStack {
                Button(model.isRunning ? "停止" : "起動") {
                    model.isRunning ? model.stop() : model.start()
                }
                .keyboardShortcut(.defaultAction)
                Button("設定を保存") { model.saveSettings() }
                    .disabled(model.isRunning)
            }
            Text(model.status)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(28)
    }
}

@MainActor
final class EmulatorModel: ObservableObject {
    @Published var sdkRoot: String
    @Published var avdName: String
    @Published var packageName: String
    @Published private(set) var status = "起動待機中"
    @Published private(set) var isRunning = false
    private var emulator: Process?

    init(defaults: UserDefaults = .standard) {
        sdkRoot = defaults.string(forKey: "sdkRoot")
            ?? ProcessInfo.processInfo.environment["ANDROID_SDK_ROOT"]
            ?? "\(NSHomeDirectory())/Library/Android/sdk"
        avdName = defaults.string(forKey: "avdName") ?? "PlayStore"
        packageName = defaults.string(forKey: "packageName") ?? ""
    }

    func saveSettings() {
        UserDefaults.standard.set(sdkRoot, forKey: "sdkRoot")
        UserDefaults.standard.set(avdName, forKey: "avdName")
        UserDefaults.standard.set(packageName, forKey: "packageName")
        status = "設定を保存しました"
    }

    func start() {
        guard !avdName.isEmpty else { status = "AVD名を入力してください"; return }
        let emulatorURL = URL(fileURLWithPath: sdkRoot).appendingPathComponent("emulator/emulator")
        let adbURL = URL(fileURLWithPath: sdkRoot).appendingPathComponent("platform-tools/adb")
        guard FileManager.default.isExecutableFile(atPath: emulatorURL.path),
              FileManager.default.isExecutableFile(atPath: adbURL.path) else {
            status = "Android SDKのemulatorまたはadbが見つかりません"
            return
        }
        let process = Process()
        process.executableURL = emulatorURL
        process.arguments = ["@\(avdName)", "-gpu", "host", "-no-snapshot", "-no-boot-anim"]
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        do {
            try process.run()
            emulator = process
            isRunning = true
            status = "AVDを起動しています…"
            waitForBoot(adbURL: adbURL)
        } catch {
            status = "起動に失敗しました: \(error.localizedDescription)"
        }
    }

    func stop() {
        emulator?.terminate()
        emulator = nil
        isRunning = false
        status = "停止しました"
    }

    private func waitForBoot(adbURL: URL) {
        Task { @MainActor in
            for _ in 0..<120 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard isRunning else { return }
                if run(adbURL, arguments: ["shell", "getprop", "sys.boot_completed"]) == "1" {
                    if packageName.isEmpty {
                        status = "AVDの起動が完了しました"
                    } else if run(adbURL, arguments: ["shell", "monkey", "-p", packageName, "1"]) != nil {
                        status = "ゲームを起動しました: \(packageName)"
                    } else {
                        status = "AVDは起動しましたが、ゲームを起動できませんでした"
                    }
                    return
                }
            }
            status = "AVDの起動がタイムアウトしました"
        }
    }

    private func run(_ executable: URL, arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
