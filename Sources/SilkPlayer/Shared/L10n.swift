import Foundation

extension Notification.Name {
    public static let silkLanguageDidChange = Notification.Name("silkLanguageDidChange")
}

/// Centralized Bilingual Localization Manager (Chinese & English)
public enum L10n {
    /// Detects whether current preferred language is Chinese
    public static var isChinese: Bool {
        if let lang = UserDefaults.standard.string(forKey: "appLanguage") {
            return lang == AppLanguage.zhHans.rawValue
        }
        if let preferred = Locale.preferredLanguages.first {
            return preferred.hasPrefix("zh")
        }
        return true
    }

    /// Returns localized string based on current environment
    public static func tr(_ en: String, _ zh: String) -> String {
        isChinese ? zh : en
    }

    // MARK: - Common Actions & States
    public static var open: String { tr("Open", "打开") }
    public static var openFile: String { tr("Open File", "打开文件") }
    public static var play: String { tr("Play", "播放") }
    public static var pause: String { tr("Pause", "暂停") }
    public static var playNow: String { tr("Play Now", "立即播放") }
    public static var playing: String { tr("Playing", "正在播放") }
    public static var loading: String { tr("Loading", "正在加载") }
    public static var playbackEnded: String { tr("Playback Ended", "播放结束") }
    public static var mediaSourceDisconnected: String { tr("Storage volume disconnected", "媒体源已断开连接") }
    public static var networkStreamDisconnected: String { mediaSourceDisconnected } // Compatibility alias

    // MARK: - Playback Controls & Navigation
    public static var playback: String { tr("Playback", "播放") }
    public static var playbackSpeed: String { tr("Playback Speed", "播放速度") }
    public static var speedNormal: String { tr("Normal (1.0x)", "正常 (1.0x)") }
    public static var speedIncrease: String { tr("Increase Speed (+0.25x)", "加快播放速度 (+0.25x)") }
    public static var speedDecrease: String { tr("Decrease Speed (-0.25x)", "减慢播放速度 (-0.25x)") }
    public static var speedReset: String { tr("Reset Speed (1.0x)", "重置播放速度 (1.0x)") }

    public static var previousTrack: String { tr("Previous Track", "上一项") }
    public static var nextTrack: String { tr("Next Track", "下一项") }
    public static var noPreviousTrack: String { tr("No previous track", "没有上一项") }
    public static var noNextTrack: String { tr("No next track", "没有下一项") }

    public static var stepBackward5s: String { tr("Step backward 5 seconds", "快退 5 秒") }
    public static var stepForward5s: String { tr("Step forward 5 seconds", "快进 5 秒") }
    public static var jumpBackward30s: String { tr("Jump Backward 30 Seconds", "快退 30 秒") }
    public static var jumpForward30s: String { tr("Jump Forward 30 Seconds", "快进 30 秒") }

    public static var frameStep: String { tr("Frame Step", "逐帧微调") }
    public static var frameStepForward: String { tr("Frame Step Forward (])", "下一帧 / 逐帧前进 (])") }
    public static var frameStepBackward: String { tr("Frame Step Backward ([)", "上一帧 / 逐帧后退 ([)") }

    // MARK: - Audio & Volume
    public static var audioTrack: String { tr("Audio", "音频") }
    public static var audioTrackSelection: String { tr("Audio Track Selection", "音轨选择") }
    public static var noAudioTracks: String { tr("No Audio Tracks Available", "无可用音轨") }
    public static var cycleAudioTrack: String { tr("Cycle Audio Track (A)", "切换下一个音轨 (A)") }
    public static var muteAudio: String { tr("Mute audio", "静音") }
    public static var unmuteAudio: String { tr("Unmute audio", "取消静音") }
    public static var muteUnmute: String { tr("Mute / Unmute", "静音 / 取消静音") }
    public static var volumeSlider: String { tr("Volume slider", "音量调节") }

    public static var audioDelay: String { tr("Audio Delay", "音频延迟") }
    public static var increaseAudioDelay: String { tr("Increase Audio Delay (+0.1s)", "增加音频延迟 (+0.1s)") }
    public static var decreaseAudioDelay: String { tr("Decrease Audio Delay (-0.1s)", "减小音频延迟 (-0.1s)") }
    public static var resetAudioDelay: String { tr("Reset Audio Delay (0.0s)", "重置音频延迟 (0.0s)") }

    // MARK: - Subtitles
    public static var subtitles: String { tr("Subtitles", "字幕") }
    public static var subtitleTrack: String { tr("Subtitles", "字幕") }
    public static var subtitleTrackSelection: String { tr("Subtitle Track Selection", "字幕选择") }
    public static var noSubtitles: String { tr("No Subtitles Available", "无可用字幕") }
    public static var cycleSubtitleTrack: String { tr("Cycle Subtitle Track (S)", "切换下一个字幕轨 (S)") }
    public static var loadExternalSubtitle: String { tr("Load External Subtitle...", "载入外挂字幕...") }
    public static var disableSubtitles: String { tr("Disable Subtitles", "关闭字幕") }

    public static var subtitleDelay: String { tr("Subtitle Delay", "字幕延迟") }
    public static var increaseSubtitleDelay: String { tr("Increase Subtitle Delay (+0.1s)", "增加字幕延迟 (+0.1s)") }
    public static var decreaseSubtitleDelay: String { tr("Decrease Subtitle Delay (-0.1s)", "减小字幕延迟 (-0.1s)") }
    public static var resetSubtitleDelay: String { tr("Reset Subtitle Delay (0.0s)", "重置字幕延迟 (0.0s)") }

    public static var subtitleScale: String { tr("Subtitle Size", "字幕字号") }
    public static var increaseSubtitleScale: String { tr("Increase Subtitle Size (+10%)", "放大字幕字号 (+10%)") }
    public static var decreaseSubtitleScale: String { tr("Decrease Subtitle Size (-10%)", "缩小字幕字号 (-10%)") }
    public static var resetSubtitleScale: String { tr("Reset Subtitle Size (1.0x)", "重置字幕字号 (1.0x)") }

    // MARK: - Video & Picture Adjustments
    public static var menuVideo: String { tr("Video", "视频") }
    public static var menuAudio: String { tr("Audio", "音频") }
    public static var menuPlayback: String { tr("Playback", "播放") }
    public static var menuSubtitle: String { tr("Subtitle", "字幕") }
    public static var menuWindow: String { tr("Window", "窗口") }

    public static var enterFullscreen: String { tr("Enter Fullscreen", "进入全屏") }
    public static var exitFullscreen: String { tr("Exit Fullscreen", "退出全屏") }
    public static var toggleFullscreenHelp: String { tr("Toggle Fullscreen (F / Double-Click)", "切换全屏 (按 F 或双击)") }

    public static var pictureAdjustments: String { tr("Picture Adjustments", "画质增强") }
    public static var toggleDeband: String { tr("Toggle Deband (D)", "切换去色带 (D)") }
    public static var sharpen: String { tr("Sharpen", "锐化") }
    public static var increaseSharpen: String { tr("Increase Sharpen (+0.1)", "增强锐化 (+0.1)") }
    public static var decreaseSharpen: String { tr("Decrease Sharpen (-0.1)", "降低锐化 (-0.1)") }
    public static var contrast: String { tr("Contrast", "对比度") }
    public static var increaseContrast: String { tr("Increase Contrast (+5)", "增加对比度 (+5)") }
    public static var decreaseContrast: String { tr("Decrease Contrast (-5)", "减小对比度 (-5)") }
    public static var brightness: String { tr("Brightness", "亮度") }
    public static var increaseBrightness: String { tr("Increase Brightness (+5)", "增加亮度 (+5)") }
    public static var decreaseBrightness: String { tr("Decrease Brightness (-5)", "减小亮度 (-5)") }
    public static var resetPictureAdjustments: String { tr("Reset Picture Adjustments", "重置画面调整") }

    public static var aspectRatio: String { tr("Aspect Ratio", "宽高比") }
    public static var aspectRatioDefault: String { tr("Default", "默认") }
    public static var aspectRatio16_9: String { tr("16:9", "16:9") }
    public static var aspectRatio4_3: String { tr("4:3", "4:3") }
    public static var aspectRatio235_1: String { tr("2.35:1", "2.35:1") }

    public static var floatOnTop: String { tr("Float on Top", "置顶浮动") }
    public static var fitToVideo: String { tr("Fit to Video", "贴合画面尺寸") }
    public static var fitToVideo100: String { tr("Actual Size (1:1 / 100%)", "原始尺寸 (1:1 / 100%)") }
    public static var fitToVideo200: String { tr("Double Size (2:1 / 200%)", "双倍尺寸 (2:1 / 200%)") }

    // MARK: - Canvas & Dialogs
    public static var dragVideoHerePrompt: String { tr("Drag media files here to play, or open from disk", "拖拽媒体文件至此处播放，或从磁盘打开") }
    public static var dropToPlay: String { tr("Drop to Play Video / Attach Subtitles", "拖放以播放视频或载入字幕") }
    public static var chooseVideoDialog: String { tr("Choose media file to play", "选择要播放的媒体文件") }
    public static var selectSubtitleDialog: String { tr("Select external subtitle file (.srt, .ass, .vtt)", "选择外挂字幕文件 (.srt, .ass, .vtt)") }
    public static var showInFinder: String { tr("Show in Finder", "在访达中显示") }
    public static var copyPath: String { tr("Copy Path", "拷贝路径") }

    // MARK: - Playlist & Inspector
    public static var playlist: String { tr("Playlist", "播放列表") }
    public static var emptyPlaylist: String { tr("Playlist is Empty", "播放列表为空") }
    public static var dragVideoToPlaylist: String { tr("Drag media files here to add to playlist", "拖拽音视频文件至此添加至播放列表") }
    public static var playlistDrawerHelp: String { tr("Playlist Drawer (P)", "播放列表 (P)") }
    public static var clearPlaylist: String { tr("Clear Playlist", "清空播放列表") }
    public static var clearAll: String { tr("Clear All", "一键清空") }
    public static func playlistItemsCount(_ count: Int) -> String {
        if isChinese {
            return "\(count) 部影片"
        } else {
            return "\(count) \(count == 1 ? "item" : "items")"
        }
    }

    public static var mediaInspectorTitle: String { tr("Media Properties", "媒体属性") }
    public static var mediaInspectorHelp: String { tr("Media Properties (⌘I)", "媒体属性 (⌘I)") }
    public static var videoInformation: String { tr("Video Info", "视频参数") }
    public static var resolution: String { tr("Resolution", "分辨率") }
    public static var videoCodec: String { tr("Video Codec", "视频编码") }
    public static var audioInformation: String { tr("Audio Info", "音频参数") }
    public static var copyInfo: String { tr("Copy Info", "一键复制") }
    public static var copied: String { tr("Copied", "已复制") }



    // MARK: - Settings & App Info
    public static var settings: String { tr("Settings", "设置") }
    public static var playbackContinuity: String { tr("Playback Continuity", "播放连续性") }
    public static var keyboardShortcuts: String { tr("Keyboard Shortcuts Cheatsheet", "键盘快捷键速查表") }
    public static var keyboardShortcutsTitle: String { tr("SilkPlayer Keyboard Shortcuts", "SilkPlayer 键盘快捷键") }
    public static var aboutSilkPlayer: String { tr("About SilkPlayer", "关于 SilkPlayer") }
}
