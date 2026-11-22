import Foundation
import AVFoundation
#if canImport(Libavformat)
import Libavformat
#endif

/// Lightweight asynchronous duration probe for media files in playlist and library.
public enum MediaDurationProbe: Sendable {

    /// Probes duration in seconds for a file without decoding streams or loading deep frames.
    public static func probeDuration(at path: String) async -> Double {
        guard FileManager.default.fileExists(atPath: path) else { return 0.0 }

        // 1. First attempt: AVURLAsset asynchronous duration loading (extremely fast for MP4, MOV, M4V, MP3, etc.)
        let url = URL(fileURLWithPath: path)
        let asset = AVURLAsset(url: url)
        if let dur = try? await asset.load(.duration), dur.isNumeric && dur.seconds > 0 {
            return dur.seconds
        }

        #if canImport(Libavformat)
        // 2. Second attempt: Direct FFmpeg avformat header inspection (for MKV, TS, AVI, WebM, etc.)
        return probeWithFFmpeg(path: path)
        #else
        return 0.0
        #endif
    }

    #if canImport(Libavformat)
    private static func probeWithFFmpeg(path: String) -> Double {
        var localCtx: UnsafeMutablePointer<AVFormatContext>? = nil
        guard avformat_open_input(&localCtx, path, nil, nil) == 0, let fCtx = localCtx else { return 0.0 }
        defer {
            var tmp: UnsafeMutablePointer<AVFormatContext>? = fCtx
            avformat_close_input(&tmp)
        }
        if fCtx.pointee.duration > 0 {
            return Double(fCtx.pointee.duration) / Double(AV_TIME_BASE)
        }
        if avformat_find_stream_info(fCtx, nil) >= 0 && fCtx.pointee.duration > 0 {
            return Double(fCtx.pointee.duration) / Double(AV_TIME_BASE)
        }
        return 0.0
    }
    #endif
}
