import Foundation

/// Centralized helper for media format classification, resolution tier detection,
/// and clipboard-ready media specification formatting.
public enum SilkMediaFormatHelper {

    /// Classifies video dimensions into industry-standard resolution tier badges.
    /// Uses max dimension (and min dimension) to accurately handle cropped widescreen releases
    /// (e.g., 3832×1600 cropped 4K UHD, 1920×800 cropped 1080p, 1280×536 cropped 720p).
    public static func resolutionBadge(width: Int, height: Int) -> String? {
        guard width > 0 && height > 0 else { return nil }
        let maxDim = max(width, height)
        let minDim = min(width, height)

        if maxDim >= 7200 || minDim >= 4000 {
            return "8K"
        } else if maxDim >= 3600 || minDim >= 2000 {
            return "4K UHD"
        } else if maxDim >= 2400 || minDim >= 1350 {
            return "2K QHD"
        } else if maxDim >= 1800 || minDim >= 960 {
            return "1080p HD"
        } else if maxDim >= 1200 || minDim >= 680 {
            return "720p HD"
        } else if maxDim >= 600 || minDim >= 360 {
            return "SD"
        }
        return nil
    }

    /// Returns a human-friendly resolution string.
    /// If recognized, returns standard badge (e.g. "4K UHD"); otherwise falls back to "\(width)×\(height)".
    public static func resolutionText(width: Int, height: Int) -> String {
        if let badge = resolutionBadge(width: width, height: height) {
            return badge
        }
        if width > 0 && height > 0 {
            return "\(width)×\(height)"
        }
        return "—"
    }

    /// Formats all media specifications into a clean, structured, clipboard-ready summary
    /// focusing on authentic video, audio, and subtitle specifications.
    @MainActor
    public static func formattedMediaInfo(
        title: String = "",
        filePath: String? = nil,
        videoWidth: Int = 0,
        videoHeight: Int = 0,
        videoFps: Double = 0.0,
        videoCodec: String = "",
        isHDRContent: Bool = false,
        isDolbyVision: Bool = false,
        hdrFormatString: String = "",
        videoAspectRatio: String = "auto",
        videoRotation: Int = 0,
        speed: Double = 1.0,
        audioTracks: [TrackItem] = [],
        selectedAudioTrackId: Int = -1,
        subtitleTracks: [TrackItem] = [],
        selectedSubtitleTrackId: Int = -1
    ) -> String {
        var lines: [String] = []
        lines.append("【SilkPlayer \(L10n.tr("Media Info", "影片媒体信息"))】")

        let effectiveTitle: String
        if !title.isEmpty {
            effectiveTitle = title
        } else if let filePath = filePath, !filePath.isEmpty {
            effectiveTitle = URL(fileURLWithPath: filePath).lastPathComponent
        } else {
            effectiveTitle = ""
        }

        if !effectiveTitle.isEmpty {
            lines.append("• \(L10n.tr("Title", "影片名称")): \(effectiveTitle)")
        }

        if videoWidth > 0 && videoHeight > 0 {
            let badge = resolutionBadge(width: videoWidth, height: videoHeight)
            let resStr = (badge != nil)
                ? "\(videoWidth) × \(videoHeight) (\(badge!))"
                : "\(videoWidth) × \(videoHeight)"
            lines.append("• \(L10n.tr("Resolution", "画面分辨率")): \(resStr)")
        }

        if !videoCodec.isEmpty && videoCodec != "Unknown" {
            lines.append("• \(L10n.tr("Video Codec", "视频编码")): \(videoCodec.uppercased())")
        }

        if videoFps > 0 {
            lines.append("• \(L10n.tr("Frame Rate", "视频帧率")): \(String(format: "%.2f fps", videoFps))")
        }

        if isDolbyVision {
            let dvStr = hdrFormatString.isEmpty ? "Dolby Vision" : hdrFormatString
            lines.append("• \(L10n.tr("Dynamic Range", "动态范围")): \(dvStr)")
        } else if isHDRContent {
            let hdrStr = hdrFormatString.isEmpty ? "HDR10" : hdrFormatString
            lines.append("• \(L10n.tr("Dynamic Range", "动态范围")): \(hdrStr)")
        } else {
            lines.append("• \(L10n.tr("Dynamic Range", "动态范围")): SDR (Standard Dynamic Range)")
        }

        lines.append("• \(L10n.tr("Rendering Pipeline", "渲染管线")): Metal Hardware Direct (Zero-Copy)")

        if !videoAspectRatio.isEmpty && videoAspectRatio != "auto" {
            lines.append("• \(L10n.tr("Aspect Ratio", "画面比例")): \(videoAspectRatio)")
        }

        if videoRotation != 0 {
            lines.append("• \(L10n.tr("Rotation", "画面旋转")): \(videoRotation)°")
        }

        if speed != 1.0 {
            lines.append("• \(L10n.tr("Playback Speed", "播放速度")): \(String(format: "%.2fx", speed))")
        }

        // Audio Track & Engine
        if let selectedAudio = audioTracks.first(where: { $0.id == selectedAudioTrackId }) {
            lines.append("• \(L10n.tr("Audio Track", "音频轨道")): \(selectedAudio.displayName)")
        } else if !audioTracks.isEmpty && selectedAudioTrackId >= 0 {
            lines.append("• \(L10n.tr("Audio Track", "音频轨道")): #\(selectedAudioTrackId)")
        } else {
            lines.append("• \(L10n.tr("Audio Track", "音频轨道")): \(L10n.tr("No Audio Stream", "无音频流"))")
        }
        lines.append("• \(L10n.tr("Audio Engine", "音频引擎")): Native CoreAudio (AudioQueue Low-Latency)")

        // Subtitles (Active Track)
        let sub = selectedSubtitleTrackId > 0
            ? (subtitleTracks.first(where: { $0.id == selectedSubtitleTrackId })?.displayName ?? "#\(selectedSubtitleTrackId)")
            : L10n.tr("Disabled / None", "已关闭 / 无")
        lines.append("• \(L10n.tr("Current Subtitle", "当前字幕")): \(sub)")

        return lines.joined(separator: "\n")
    }

    /// Convenience overload accepting a PlayerControllable instance
    @MainActor
    public static func formattedMediaInfo(
        for player: any PlayerControllable,
        title: String? = nil,
        videoCodec: String? = nil,
        selectedAudioTrackId: Int? = nil,
        selectedSubtitleTrackId: Int? = nil
    ) -> String {
        let effTitle = title ?? (player.mediaTitle.isEmpty ? (player.currentFilePath != nil ? URL(fileURLWithPath: player.currentFilePath!).lastPathComponent : "") : player.mediaTitle)
        let effCodec = videoCodec ?? player.videoCodec
        let effAudioId = selectedAudioTrackId ?? (player.selectedAudioTrackId >= 0 ? player.selectedAudioTrackId : (player.audioTracks.first?.id ?? -1))
        let effSubId = selectedSubtitleTrackId ?? player.selectedSubtitleTrackId

        return formattedMediaInfo(
            title: effTitle,
            filePath: player.currentFilePath,
            videoWidth: player.videoWidth,
            videoHeight: player.videoHeight,
            videoFps: player.videoFps,
            videoCodec: effCodec,
            isHDRContent: player.isHDRContent,
            isDolbyVision: player.isDolbyVision,
            hdrFormatString: player.hdrFormatString,
            videoAspectRatio: player.videoAspectRatio,
            videoRotation: player.videoRotation,
            speed: player.speed,
            audioTracks: player.audioTracks,
            selectedAudioTrackId: effAudioId,
            subtitleTracks: player.subtitleTracks,
            selectedSubtitleTrackId: effSubId
        )
    }
}
