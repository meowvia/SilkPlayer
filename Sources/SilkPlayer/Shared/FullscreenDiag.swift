import Foundation
import AppKit
import os.log

public final class FullscreenDiag: @unchecked Sendable {
    public static let shared = FullscreenDiag()
    private static let logger = Logger(subsystem: "com.silkplayer.SilkPlayer", category: "Fullscreen")

    private let logFileURL: URL
    private let fileHandle: FileHandle?
    private let lock = NSLock()
    private let dateFormatter: ISO8601DateFormatter

    private init() {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let logsDir = homeDir.appendingPathComponent("Library/Logs/SilkPlayer", isDirectory: true)

        try? fileManager.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let fileURL = logsDir.appendingPathComponent("fullscreen.log")
        self.logFileURL = fileURL

        if !fileManager.fileExists(atPath: fileURL.path) {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }
        self.fileHandle = try? FileHandle(forWritingTo: fileURL)
        self.fileHandle?.seekToEndOfFile()

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.dateFormatter = df
    }

    @MainActor
    public static func log(_ message: String, window: NSWindow? = nil, player: (any PlayerControllable)? = nil) {
        shared.write(message: message, window: window, player: player)
    }

    @MainActor
    private func write(message: String, window: NSWindow?, player: (any PlayerControllable)?) {
        lock.lock()
        defer { lock.unlock() }

        let timestamp = dateFormatter.string(from: Date())
        var details: [String] = []

        if let win = window {
            let f = win.frame
            details.append("winFrame=(\(Int(f.origin.x)),\(Int(f.origin.y)),\(Int(f.width))x\(Int(f.height)))")
            if let screen = win.screen {
                let sf = screen.frame
                let vf = screen.visibleFrame
                let hz = screen.maximumFramesPerSecond
                details.append("screen=(\(Int(sf.width))x\(Int(sf.height))@\(hz)Hz visible=\(Int(vf.width))x\(Int(vf.height)))")
            }
        }
        details.append("screensCount=\(NSScreen.screens.count)")

        if let p = player {
            let w = p.videoWidth
            let h = p.videoHeight
            let isPlaying = p.isPlaying
            details.append("video=(\(w)x\(h) playing=\(isPlaying))")
        }

        let line = "[\(timestamp)] [FullscreenDiag] \(message) | \(details.joined(separator: " "))\n"

        Self.logger.info("\(line, privacy: .public)")

        if let handle = fileHandle, let data = line.data(using: .utf8) {
            handle.write(data)
            try? handle.synchronize() // fsync immediately to ensure durability on kernel panic/watchdog crash
        }
    }
}
