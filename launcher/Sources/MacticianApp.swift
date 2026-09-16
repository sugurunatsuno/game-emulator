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
    private var avdHome: String
    private let serial = "emulator-5554"

    init(defaults: UserDefaults = .standard) {
        let savedSDK = defaults.string(forKey: "sdkRoot")
        let detectedSDK = savedSDK.flatMap { Self.hasAndroidTools($0) ? $0 : nil }
            ?? Self.defaultSDKRoot()
        sdkRoot = detectedSDK
        avdHome = Self.defaultAVDHome(sdkRoot: detectedSDK)
        avdName = defaults.string(forKey: "avdName")
            ?? Self.firstAVDName(sdkRoot: detectedSDK, avdHome: avdHome)
            ?? "PlayStore"
        packageName = defaults.string(forKey: "packageName") ?? ""
    }

    private static func defaultSDKRoot() -> String {
        let candidates = [
            ProcessInfo.processInfo.environment["ANDROID_SDK_ROOT"],
            "\(NSHomeDirectory())/Library/Application Support/Mactician/sdk",
            "/Volumes/SSD-4TB/MacticianData/sdk",
            "\(NSHomeDirectory())/Library/Android/sdk"
        ].compactMap { $0 }
        return candidates.first(where: hasAndroidTools) ?? candidates.last!
    }

    private static func hasAndroidTools(_ root: String) -> Bool {
        FileManager.default.isExecutableFile(atPath: "\(root)/emulator/emulator")
            && FileManager.default.isExecutableFile(atPath: "\(root)/platform-tools/adb")
    }

    private static func defaultAVDHome(sdkRoot: String) -> String {
        let candidates = [
            ProcessInfo.processInfo.environment["ANDROID_AVD_HOME"],
            URL(fileURLWithPath: sdkRoot).deletingLastPathComponent()
                .appendingPathComponent("avd").path,
            "\(NSHomeDirectory())/Library/Application Support/Mactician/avd",
            "\(NSHomeDirectory())/.android/avd"
        ].compactMap { $0 }
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) })
            ?? candidates[1]
    }

    private static func firstAVDName(sdkRoot: String, avdHome: String) -> String? {
        let emulatorURL = URL(fileURLWithPath: sdkRoot).appendingPathComponent("emulator/emulator")
        let process = Process()
        let pipe = Pipe()
        process.executableURL = emulatorURL
        process.arguments = ["-list-avds"]
        process.environment = ["ANDROID_AVD_HOME": avdHome]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .split(whereSeparator: \.isNewline).first.map(String.init)
        } catch {
            return nil
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(sdkRoot, forKey: "sdkRoot")
        UserDefaults.standard.set(avdName, forKey: "avdName")
        UserDefaults.standard.set(packageName, forKey: "packageName")
        avdHome = Self.defaultAVDHome(sdkRoot: sdkRoot)
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
        process.environment = ProcessInfo.processInfo.environment.merging(
            ["ANDROID_AVD_HOME": avdHome]
        ) { _, new in new }
        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.emulator = nil
                self.isRunning = false
                self.status = "AVDが終了しました（終了コード: \(process.terminationStatus)）"
            }
        }
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
                if run(adbURL, arguments: ["-s", serial, "shell", "getprop", "sys.boot_completed"]) == "1" {
                    if packageName.isEmpty {
                        status = "AVDの起動が完了しました"
                    } else if run(adbURL, arguments: ["-s", serial, "shell", "monkey", "-p", packageName, "1"]) != nil {
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
