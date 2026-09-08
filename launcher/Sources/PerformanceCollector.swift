import AppKit
import Darwin
import Foundation

// Uniformly scheduled short samples keep OCR and ADB work off the frame path.
// Screenshots only cross pipes in memory. No images, OCR text, layers or PIDs
// enter the telemetry payload. Scene labels describe matching sample endpoints.
final class PerformanceCollector {
    private let queue = DispatchQueue(label: "dev.sergeinaumov.mactician.performance", qos: .utility)
    private let lock = NSLock()
    private let adb: URL
    private let classifier: URL
    private let package: String
    private let targetPID: pid_t
    private let publish: (PerformanceSample) -> Void
    private var stopped = false
    private var process: Process?
    private var enabledTimeStats = false
    private var exposure = "unknown"

    init(adb: URL, classifier: URL, package: String, targetPID: pid_t, publish: @escaping (PerformanceSample) -> Void) {
        self.adb = adb; self.classifier = classifier; self.package = package
        self.targetPID = targetPID; self.publish = publish
    }

    func start() {
        queue.asyncAfter(deadline: .now() + Double.random(in: 5...15)) { [weak self] in self?.sample() }
    }

    func stop() {
        lock.lock(); stopped = true; let running = process; lock.unlock()
        if running?.isRunning == true { running?.terminate() }
        queue.async { [self] in disableTimeStats() }
    }

    private var isStopped: Bool { lock.lock(); defer { lock.unlock() }; return stopped }

    private func foreground() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] else { return false }
        return windows.contains { row in
            (row[kCGWindowOwnerPID] as? NSNumber)?.int32Value == targetPID &&
                (row[kCGWindowLayer] as? NSNumber)?.intValue == 0
        }
    }

    private func sample() {
        guard !isStopped else { return }
        let began = ProcessInfo.processInfo.systemUptime
        var result = PerformanceSample()
        result.thermalState = ProcessInfo.processInfo.thermalState.rawValue
        if !foreground() {
            result.background = true
        } else {
            if let data = run(URL(fileURLWithPath: "/bin/ps"), ["-o", "rss=", "-p", String(targetPID)], maximumBytes: 128),
               let text = String(data: data, encoding: .utf8), let kb = Int64(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                result.residentMB = min(1_048_576, max(0, kb / 1024))
            }
            if exposure == "unknown" { exposure = cacheExposure() }
            result.cacheState = exposure
            let beforeScene = scene()
            // The dedicated Mactician AVD has one collector. Clear once per window
            // to bound historical layer entries, then subtract two snapshots.
            // The guest may execute enable even if the ADB response is lost or
            // cancelled. Always attempt cleanup after dispatching this command.
            enabledTimeStats = true
            if shell("dumpsys SurfaceFlinger --timestats -clear -enable") != nil {
                pause(0.25) // allow the active layer to register before the baseline
                if let before = timeStats(), !isStopped, foreground() {
                    let measuredAt = ProcessInfo.processInfo.systemUptime
                    var focused = true
                    for _ in 0..<20 {
                        if isStopped { break }
                        Thread.sleep(forTimeInterval: 0.1)
                        if !foreground() { focused = false }
                    }
                    if !isStopped, let after = timeStats() {
                        result.durationMS = Int64((ProcessInfo.processInfo.systemUptime - measuredAt) * 1000)
                        let afterScene = scene()
                        if focused, foreground() {
                            result.histogram = SurfaceFlingerTimeStats.delta(before: before, after: after)
                            result.scene = PerformanceScene.bracket(beforeScene, afterScene)
                        }
                    }
                }
            }
            disableTimeStats()
        }
        let totalMS = Int64((ProcessInfo.processInfo.systemUptime - began) * 1000)
        result.collectorMS = max(0, totalMS - (result.durationMS > 0 ? 2000 : 0))
        guard !isStopped else { return }
        publish(result)
        // Back off on expensive machines rather than spending a fixed OCR budget
        // at the expense of gameplay. This is a wall-time duty budget, not CPU usage.
        let delay = max(Double.random(in: 45...75), Double(result.collectorMS) / 10)
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in self?.sample() }
    }

    private func pause(_ seconds: Double) {
        let until = ProcessInfo.processInfo.systemUptime + seconds
        while !isStopped, ProcessInfo.processInfo.systemUptime < until { Thread.sleep(forTimeInterval: 0.05) }
    }

    private func scene() -> PerformanceScene {
        guard FileManager.default.isExecutableFile(atPath: classifier.path),
              let png = runADB(["exec-out", "screencap", "-p"], maximumBytes: 32*1024*1024),
              let result = run(classifier, ["--telemetry-stdin"], input: png, maximumBytes: 2048) else { return PerformanceScene() }
        return PerformanceScene.decode(result)
    }

    private func timeStats() -> SurfaceFlingerTimeStats.Layer? {
        guard let data = shell("dumpsys SurfaceFlinger --timestats -dump"), let text = String(data: data, encoding: .utf8) else { return nil }
        return SurfaceFlingerTimeStats.parse(text, package: package)
    }

    private func cacheExposure() -> String {
        // Fixed allowlisted packages only; never evaluate data received from the server.
        guard [GameEdition.global.packageName, GameEdition.vietnam.packageName].contains(package) else { return "unknown" }
        let command = "p=$(pidof \(package)); [ -n \"$p\" ] && [ -r /proc/$p/maps ] || exit 1; v=$(getprop debug.mactician.vk_view_cache); if grep -q libVkLayer_Mactician_buffer_view_cache.so /proc/$p/maps; then [ \"$v\" = 1 ] && echo enabled || echo unknown; elif [ \"$v\" != 1 ]; then echo disabled; else echo unknown; fi"
        guard let data = shell(command), let text = String(data: data, encoding: .utf8) else { return "unknown" }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return ["enabled", "disabled"].contains(value) ? value : "unknown"
    }

    private func disableTimeStats() {
        guard enabledTimeStats else { return }
        _ = runADB(["shell", "dumpsys SurfaceFlinger --timestats -disable"], maximumBytes: 1024, allowStopped: true)
        enabledTimeStats = false
    }

    private func shell(_ command: String) -> Data? { runADB(["shell", command], maximumBytes: 2*1024*1024) }

    private func runADB(_ arguments: [String], maximumBytes: Int, allowStopped: Bool = false) -> Data? {
        run(adb, ["-P", "5038", "-s", "emulator-5582"] + arguments, maximumBytes: maximumBytes, allowStopped: allowStopped)
    }

    private func run(_ executable: URL, _ arguments: [String], input: Data? = nil, maximumBytes: Int, allowStopped: Bool = false) -> Data? {
        let child = Process(), output = Pipe(), inputPipe = Pipe()
        child.executableURL = executable; child.arguments = arguments
        child.standardOutput = output; child.standardError = FileHandle.nullDevice
        child.standardInput = input == nil ? FileHandle.nullDevice : inputPipe
        child.environment = ProcessInfo.processInfo.environment.merging([
            "ANDROID_ADB_SERVER_PORT": "5038", "ADB_MDNS_AUTO_CONNECT": "", "TFT_CLASSIFIER_DEBUG": "0"
        ]) { _,new in new }
        lock.lock()
        guard !stopped || allowStopped else { lock.unlock(); return nil }
        do { try child.run(); process = child; lock.unlock() } catch { lock.unlock(); return nil }
        let timeout = DispatchWorkItem { if child.isRunning { kill(child.processIdentifier, SIGKILL) } }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10, execute: timeout)
        defer {
            timeout.cancel()
            if child.isRunning { kill(child.processIdentifier, SIGKILL) }
            child.waitUntilExit()
            try? output.fileHandleForReading.close()
            lock.lock(); if process === child { process = nil }; lock.unlock()
        }
        if let input {
            _ = fcntl(inputPipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
            DispatchQueue.global(qos: .utility).async {
                try? inputPipe.fileHandleForWriting.write(contentsOf: input)
                try? inputPipe.fileHandleForWriting.close()
            }
        }
        var data = Data()
        while let chunk = try? output.fileHandleForReading.read(upToCount: 65536), !chunk.isEmpty {
            guard data.count + chunk.count <= maximumBytes else { return nil }
            data.append(chunk)
        }
        child.waitUntilExit()
        return child.terminationStatus == 0 ? data : nil
    }
}
