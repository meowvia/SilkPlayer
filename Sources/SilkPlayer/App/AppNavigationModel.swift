import SwiftUI

@MainActor
@Observable
public final class AppNavigationModel {
    public static let shared = AppNavigationModel()

    public enum PlaybackState: Equatable {
        case idle
        case playing(url: URL)
    }

    public enum InspectorTab: Equatable {
        case none
        case info
        case video
        case audio
        case subtitles
        case playlist
    }

    public var state: PlaybackState = .idle
    public var activeInspectorTab: InspectorTab = .none
    public var isAlwaysOnTop: Bool = false
    public var videoRotation: Int = 0 // 0, 90, 180, 270

    public var isInspectorOpen: Bool {
        get { activeInspectorTab != .none && activeInspectorTab != .playlist }
        set {
            if newValue {
                if activeInspectorTab == .none || activeInspectorTab == .playlist {
                    activeInspectorTab = .info
                }
            } else {
                if activeInspectorTab != .playlist {
                    activeInspectorTab = .none
                }
            }
        }
    }

    public var isPlaylistDrawerOpen: Bool {
        get { activeInspectorTab == .playlist }
        set {
            if newValue {
                activeInspectorTab = .playlist
            } else if activeInspectorTab == .playlist {
                activeInspectorTab = .none
            }
        }
    }

    public func toggleInspector(tab: InspectorTab = .info) {
        if activeInspectorTab == tab || (isInspectorOpen && tab == .info) {
            activeInspectorTab = .none
        } else {
            activeInspectorTab = tab
        }
    }

    public func togglePlaylist() {
        if activeInspectorTab == .playlist {
            activeInspectorTab = .none
        } else {
            activeInspectorTab = .playlist
        }
    }

    public func closeInspector() {
        activeInspectorTab = .none
    }

    public func rotateClockwise() {
        videoRotation = (videoRotation + 90) % 360
    }

    public func rotateCounterClockwise() {
        videoRotation = (videoRotation - 90 + 360) % 360
    }
}
