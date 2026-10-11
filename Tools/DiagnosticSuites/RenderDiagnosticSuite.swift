import Foundation
import AppKit

@MainActor
public final class RenderDiagnosticSuite {
    public static func getMemoryRSSInMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
            }
        }
        return kerr == KERN_SUCCESS ? Double(info.resident_size) / (1024.0 * 1024.0) : 0.0
    }

    private static func pumpEvents(duration: TimeInterval) async {
        let start = Date()
        while Date().timeIntervalSince(start) < duration {
            autoreleasepool {
                _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    struct MovieSample {
        let title: String
        let path: String
        let category: String
        let timestamps: [Double]
    }

    public static func runMultiClipDiagnostics() async {
        print("================================================================================")
        print(" SILKPLAYER MULTI-CLIP RENDERING & COLOR PIPELINE DIAGNOSTIC SUITE")
        print("================================================================================")

        let testMovies: [MovieSample] = [
            MovieSample(
                title: "极限审判 (Mercy)",
                path: "/Volumes/HDD2T/影音娱乐/电影/极限审判/极限审判.2160p.HD中英双字[最新电影www.5266ys.com].mp4",
                category: "4K SDR H264 (User Issue Target)",
                timestamps: [60.0, 187.0, 300.0, 600.0]
            ),
            MovieSample(
                title: "盗亦有道 (Goodfellas)",
                path: "/Volumes/HDD2T/影音娱乐/电影/盗亦有道/盗亦有道.2160p.HD中英双字[最新电影www.5266ys.com].mp4",
                category: "4K SDR H264",
                timestamps: [120.0, 300.0, 900.0]
            ),
            MovieSample(
                title: "送院途中 (Vital Signs)",
                path: "/Volumes/HDD2T/影音娱乐/电影/送院途中/送院途中.1080p.BD粤语中字[最新电影www.5266ys.com].mp4",
                category: "1080p SDR H264",
                timestamps: [90.0, 240.0]
            ),
            MovieSample(
                title: "麦克白 (Macbeth)",
                path: "/Volumes/HDD2T/影音娱乐/电影/麦克白/Macbeth.2015.Bluray.1080p.DTS-HDMA5.1.x265.10bit-DreamHD.mkv",
                category: "1080p SDR 10-bit HEVC",
                timestamps: [150.0, 450.0]
            ),
            MovieSample(
                title: "红雀 (Red Sparrow)",
                path: "/Volumes/HDD2T/影音娱乐/电影/红雀/红雀.Red.Sparrow.2018.2160p.DSNP.WEB-DL.DDP5.1.Atmos.H265.HDR.DV-ParkHD.mkv",
                category: "4K HDR Dolby Vision HEVC",
                timestamps: [80.0, 300.0]
            ),
            MovieSample(
                title: "两杆大烟枪 (Lock Stock)",
                path: "/Volumes/HDD2T/影音娱乐/电影/两杆大烟枪/Lock.Stock.and.Two.Smoking.Barrels.1998.1080p.AMZN.WEB-DL.DDP5.1.H264-MOMOWEB.mkv",
                category: "1080p SDR H264",
                timestamps: [100.0, 400.0]
            )
        ]

        let outputDir = "/tmp/silk_render_diag"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        let player = PlayerCore()
        let testWindow = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 960, height: 540),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        testWindow.title = "SilkPlayer Diagnostic Window"
        let containerView = MPVContainerView(playerCore: player)
        testWindow.contentView = containerView
        testWindow.orderFront(nil)
        player.hostWindow = testWindow

        print("[Environment] Window Mode: YES | Window Frame: \(testWindow.frame)")
        print("[Environment] Screen Backing Scale: \(testWindow.screen?.backingScaleFactor ?? 1.0)")
        print("[Environment] Screen ColorSpace: \(testWindow.screen?.colorSpace?.localizedName ?? "unknown")")

        for movie in testMovies {
            guard FileManager.default.fileExists(atPath: movie.path) else {
                print(">> [SKIP] File does not exist: \(movie.path)")
                continue
            }

            print("\n--------------------------------------------------------------------------------")
            print(">> [TEST TARGET] \(movie.title) [\(movie.category)]")
            print("--------------------------------------------------------------------------------")

            for targetSec in movie.timestamps {
                print("\n   [*] Testing timestamp: \(targetSec)s in Window Mode...")
                player.loadFile(path: movie.path, startTime: targetSec)

                var waitIters = 0
                while !player.isLoaded && waitIters < 40 {
                    await pumpEvents(duration: 0.1)
                    waitIters += 1
                }

                guard player.isLoaded else {
                    print("       [!] Failed to load within timeout")
                    continue
                }

                player.play()
                // Play for 1.2s to decode and render steady-state frames
                await pumpEvents(duration: 1.2)

                print("       [Video Pipeline] Codec: \(player.videoCodec) | HW: \(player.hwdecCurrent)")
                print("       [Color Pipeline] HDR: \(player.isHDRContent) | Format: \(player.hdrFormatString)")
                print("       [Dimensions] Width: \(player.videoWidth) | Height: \(player.videoHeight)")

                let safeTitle = movie.title.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
                _ = "\(outputDir)/\(safeTitle)_\(Int(targetSec))s.png"

                player.takeScreenshot()
            }
        }

        print("\n================================================================================")
        print(" DIAGNOSTIC EXPERIMENT: HYPOTHESIS TESTING ON USER'S TARGET (极限审判 @ 187s)")
        print("================================================================================")

        let mercyPath = "/Volumes/HDD2T/影音娱乐/电影/极限审判/极限审判.2160p.HD中英双字[最新电影www.5266ys.com].mp4"
        if FileManager.default.fileExists(atPath: mercyPath) {
            player.loadFile(path: mercyPath, startTime: 187.0)
            var waitIters = 0
            while !player.isLoaded && waitIters < 40 {
                await pumpEvents(duration: 0.1)
                waitIters += 1
            }
            player.play()
            await pumpEvents(duration: 1.5)

            // Experiment 1: deband=no, fbo=rgba8
            print("\n   [Experiment 1: deband=no, fbo=rgba8]")
            player.setPropertyString("deband", "no")
            player.setPropertyString("fbo-format", "rgba8")
            player.setPropertyString("tone-mapping", "auto")
            player.setPropertyString("target-trc", "auto")
            await pumpEvents(duration: 0.6)
            captureAndAnalyze(player: player, name: "exp1_deband_no_rgba8", outputDir: outputDir)

            // Experiment 2: User setting (deband=yes, fbo=rgba8)
            print("\n   [Experiment 2: User setting (deband=yes, fbo=rgba8)]")
            player.setPropertyString("deband", "yes")
            player.setPropertyString("deband-iterations", "1")
            player.setPropertyString("deband-threshold", "16")
            player.setPropertyString("deband-range", "8")
            player.setPropertyString("deband-grain", "4")
            player.setPropertyString("fbo-format", "rgba8")
            player.setPropertyString("tone-mapping", "auto")
            player.setPropertyString("target-trc", "auto")
            await pumpEvents(duration: 0.6)
            captureAndAnalyze(player: player, name: "exp2_user_deband_yes_rgba8", outputDir: outputDir)

            // Experiment 3: deband=yes, fbo=auto
            print("\n   [Experiment 3: deband=yes, fbo=auto]")
            player.setPropertyString("deband", "yes")
            player.setPropertyString("fbo-format", "auto")
            player.setPropertyString("tone-mapping", "auto")
            player.setPropertyString("target-trc", "auto")
            await pumpEvents(duration: 0.6)
            captureAndAnalyze(player: player, name: "exp3_deband_yes_fbo_auto", outputDir: outputDir)

            // Experiment 4: Pure Bit-Exact (deband=no, fbo=auto, target-trc=auto)
            print("\n   [Experiment 4: Pure Bit-Exact (deband=no, fbo=auto, target-trc=auto)]")
            player.setPropertyString("deband", "no")
            player.setPropertyString("fbo-format", "auto")
            player.setPropertyString("tone-mapping", "auto")
            player.setPropertyString("target-trc", "auto")
            await pumpEvents(duration: 0.6)
            captureAndAnalyze(player: player, name: "exp4_bitexact_fbo_auto", outputDir: outputDir)

            // Experiment 5: Pure Bit-Exact with target-trc=srgb
            print("\n   [Experiment 5: Bit-Exact with target-trc=srgb]")
            player.setPropertyString("deband", "no")
            player.setPropertyString("fbo-format", "auto")
            player.setPropertyString("tone-mapping", "auto")
            player.setPropertyString("target-trc", "srgb")
            await pumpEvents(duration: 0.6)
            captureAndAnalyze(player: player, name: "exp5_bitexact_trc_srgb", outputDir: outputDir)

            // Experiment 6: Pure Bit-Exact with target-trc=bt.1886
            print("\n   [Experiment 6: Bit-Exact with target-trc=bt.1886]")
            player.setPropertyString("deband", "no")
            player.setPropertyString("fbo-format", "auto")
            player.setPropertyString("tone-mapping", "auto")
            player.setPropertyString("target-trc", "bt.1886")
            await pumpEvents(duration: 0.6)
            captureAndAnalyze(player: player, name: "exp6_bitexact_trc_bt1886", outputDir: outputDir)
        }

        player.destroy()
        testWindow.close()
        print("\n================================================================================")
        print(" DIAGNOSTICS COMPLETE. Check captures in: \(outputDir)")
        print("================================================================================")
        exit(0)
    }

    private static func analyzeImageFile(outPath: String, label: String) {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: outPath)),
              let imgRep = NSBitmapImageRep(data: data) else {
            return
        }

        let pixelW = imgRep.pixelsWide
        let pixelH = imgRep.pixelsHigh
        var zeroBlackPixels = 0
        var darkGreenPixels = 0
        var sampledDarkPixels = 0
        var totalSampled = 0

        let stepX = max(1, pixelW / 80)
        let stepY = max(1, pixelH / 80)

        for y in stride(from: 0, to: pixelH, by: stepY) {
            for x in stride(from: 0, to: pixelW, by: stepX) {
                if let col = imgRep.colorAt(x: x, y: y) {
                    totalSampled += 1
                    let r = col.redComponent
                    let g = col.greenComponent
                    let b = col.blueComponent
                    if r < 0.005 && g < 0.005 && b < 0.005 {
                        zeroBlackPixels += 1
                    }
                    if g > 0.04 && g < 0.20 && r < 0.05 && b < 0.03 {
                        darkGreenPixels += 1
                    }
                    if g < 0.20 && r < 0.20 && b < 0.20 {
                        sampledDarkPixels += 1
                    }
                }
            }
        }

        let zeroPercent = totalSampled > 0 ? (Double(zeroBlackPixels) / Double(totalSampled)) * 100.0 : 0.0
        let greenArtifactPercent = sampledDarkPixels > 0 ? (Double(darkGreenPixels) / Double(sampledDarkPixels)) * 100.0 : 0.0

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: outPath)[.size] as? Int) ?? 0
        print(String(format: "       [Analysis: %@] Sampled: %d | Black Clip (0): %.1f%% | Green Shadows: %.1f%% | Size: %d KB", label, totalSampled, zeroPercent, greenArtifactPercent, fileSize / 1024))
    }

    private static func captureAndAnalyze(player: PlayerCore, name: String, outputDir: String) {
        player.takeScreenshot()
    }
}
