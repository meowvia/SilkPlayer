import XCTest
import Foundation
@testable import SilkPlayer

final class GeometryAndTransformTests: XCTestCase {

    // MARK: - 1. PlayerGeometry.minimumContentSize & maximumSafeContentSize
    func testPlayerGeometryAspectRatios() {
        let screenVisibleSize = NSSize(width: 1920, height: 1055)
        let screenH = screenVisibleSize.height

        let testAspects: [(name: String, ratio: CGFloat)] = [
            ("Landscape 16:9", 16.0 / 9.0),
            ("Portrait 9:16", 9.0 / 16.0),
            ("Ultrawide 2.39:1", 2.39),
            ("Square 1:1", 1.0)
        ]

        for test in testAspects {
            let minSize = PlayerGeometry.minimumContentSize(for: test.ratio, screenVisibleHeight: screenH)
            let maxSize = PlayerGeometry.maximumSafeContentSize(for: test.ratio, screenVisibleSize: screenVisibleSize)

            XCTAssertGreaterThanOrEqual(minSize.width, 100.0, "\(test.name) minimum width >= 100")
            XCTAssertGreaterThanOrEqual(minSize.height, 100.0, "\(test.name) minimum height >= 100")

            XCTAssertLessThanOrEqual(maxSize.width, screenVisibleSize.width, "\(test.name) max width <= screen width")
            XCTAssertLessThanOrEqual(maxSize.height, screenVisibleSize.height, "\(test.name) max height <= screen height")

            XCTAssertLessThanOrEqual(minSize.width, maxSize.width, "\(test.name) min width <= max width")
            XCTAssertLessThanOrEqual(minSize.height, maxSize.height, "\(test.name) min height <= max height")

            let computedAspect = maxSize.width / maxSize.height
            XCTAssertLessThan(abs(computedAspect - test.ratio), 0.05, "\(test.name) aspect matches within rounding")
        }
    }

    // MARK: - 2. Rotation Target Size Pure Calculation & 4-Cycle Invariant
    func testRotationTargetSizeAcrossResolutions() {
        let screens: [(name: String, size: NSSize)] = [
            ("1080p", NSSize(width: 1920, height: 1055)),
            ("1440p", NSSize(width: 2560, height: 1415)),
            ("4K", NSSize(width: 3840, height: 2135))
        ]

        for screen in screens {
            let initialLandscape = NSSize(width: 1280, height: 720)
            let landscapeAspect: CGFloat = 16.0 / 9.0
            let portraitAspect: CGFloat = 9.0 / 16.0

            var rememberedLandscape: NSSize? = initialLandscape
            var rememberedPortrait: NSSize? = nil

            // Cycle 1: Landscape -> Portrait (90 deg)
            let rot1 = PlayerGeometry.calculateRotationTargetSize(
                currentContentSize: initialLandscape,
                targetAspect: portraitAspect,
                isTargetVertical: true,
                rememberedSize: rememberedPortrait,
                screenVisibleSize: screen.size
            )
            rememberedPortrait = rot1

            XCTAssertLessThanOrEqual(rot1.width, screen.size.width, "\(screen.name) Rot1 width <= screen width")
            XCTAssertLessThanOrEqual(rot1.height, screen.size.height, "\(screen.name) Rot1 height <= screen height")
            let rot1Aspect = rot1.width / rot1.height
            XCTAssertLessThan(abs(rot1Aspect - portraitAspect), 0.05, "\(screen.name) Rot1 aspect is portrait")

            // Cycle 2: Portrait -> Landscape (180 deg)
            let rot2 = PlayerGeometry.calculateRotationTargetSize(
                currentContentSize: rot1,
                targetAspect: landscapeAspect,
                isTargetVertical: false,
                rememberedSize: rememberedLandscape,
                screenVisibleSize: screen.size
            )
            rememberedLandscape = rot2

            XCTAssertLessThanOrEqual(rot2.width, screen.size.width, "\(screen.name) Rot2 width <= screen width")
            XCTAssertLessThanOrEqual(rot2.height, screen.size.height, "\(screen.name) Rot2 height <= screen height")
            XCTAssertLessThan(abs(rot2.width - initialLandscape.width), 1.0, "\(screen.name) Rot2 width matches initial")
            XCTAssertLessThan(abs(rot2.height - initialLandscape.height), 1.0, "\(screen.name) Rot2 height matches initial")

            // Cycle 3: Landscape -> Portrait (270 deg)
            let rot3 = PlayerGeometry.calculateRotationTargetSize(
                currentContentSize: rot2,
                targetAspect: portraitAspect,
                isTargetVertical: true,
                rememberedSize: rememberedPortrait,
                screenVisibleSize: screen.size
            )

            XCTAssertLessThan(abs(rot3.width - rot1.width), 1.0, "\(screen.name) Rot3 width matches Rot1")
            XCTAssertLessThan(abs(rot3.height - rot1.height), 1.0, "\(screen.name) Rot3 height matches Rot1")

            // Cycle 4: Portrait -> Landscape (360 / 0 deg)
            let rot4 = PlayerGeometry.calculateRotationTargetSize(
                currentContentSize: rot3,
                targetAspect: landscapeAspect,
                isTargetVertical: false,
                rememberedSize: rememberedLandscape,
                screenVisibleSize: screen.size
            )

            XCTAssertLessThan(abs(rot4.width - initialLandscape.width), 1.0, "\(screen.name) Rot4 4-cycle invariant restored")
            XCTAssertLessThan(abs(rot4.height - initialLandscape.height), 1.0, "\(screen.name) Rot4 4-cycle invariant restored")
        }
    }

    // MARK: - 3. VideoTransform All 16 Combinations & Bijective Round-Trip
    func testVideoTransformAllCombinationsBijectiveRoundTrip() {
        let angles = [0, 90, 180, 270]
        let booleans = [false, true]
        let rawW = 1920
        let rawH = 1080
        let viewSize = CGSize(width: 1280, height: 720)

        // Representative coordinates in raw video space (including corners and center)
        let testPoints: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 960, y: 540),
            CGPoint(x: 1800, y: 900),
            CGPoint(x: 1920, y: 1080)
        ]

        for angle in angles {
            for flipH in booleans {
                for flipV in booleans {
                    let transform = VideoTransform(
                        intrinsicRotation: 0,
                        userRotation: angle,
                        flipH: flipH,
                        flipV: flipV
                    )

                    for pt in testPoints {
                        let viewPt = transform.videoToView(
                            point: pt,
                            in: viewSize,
                            rawWidth: rawW,
                            rawHeight: rawH
                        )

                        guard let restoredVideoPt = transform.viewToVideo(
                            point: viewPt,
                            in: viewSize,
                            rawWidth: rawW,
                            rawHeight: rawH
                        ) else {
                            XCTFail("Failed to map view point back to video for angle=\(angle), flipH=\(flipH), flipV=\(flipV)")
                            continue
                        }

                        // Normalized difference error must be < 1e-5
                        let errX = abs(restoredVideoPt.x - pt.x) / CGFloat(rawW)
                        let errY = abs(restoredVideoPt.y - pt.y) / CGFloat(rawH)

                        XCTAssertLessThan(errX, 1e-5, "Round-trip X error for angle=\(angle), flipH=\(flipH), flipV=\(flipV)")
                        XCTAssertLessThan(errY, 1e-5, "Round-trip Y error for angle=\(angle), flipH=\(flipH), flipV=\(flipV)")
                    }
                }
            }
        }
    }

    // MARK: - 4. Window Resize & Aspect Maximize Invariants
    @MainActor
    func testWindowResizeAndAspectMaximizeInvariants() {
        let delegate = PlayerWindowDelegate()
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 150, width: 1280, height: 720),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        // 1. windowShouldZoom must return false to intercept native zoom and perform aspect-preserved zoom
        let shouldZoom = delegate.windowShouldZoom(window, toFrame: window.frame)
        XCTAssertFalse(shouldZoom, "windowShouldZoom must return false to prioritize aspect-preserved zoom")

        // 2. windowWillResize with NaN or non-positive sizes must gracefully return current frame size without crashing
        let nanSize = NSSize(width: 1280, height: CGFloat.nan)
        let safeResized = delegate.windowWillResize(window, to: nanSize)
        XCTAssertFalse(safeResized.width.isNaN, "Resized width must not be NaN")
        XCTAssertFalse(safeResized.height.isNaN, "Resized height must not be NaN")
        XCTAssertGreaterThan(safeResized.width, 0, "Resized width must be positive")
        XCTAssertGreaterThan(safeResized.height, 0, "Resized height must be positive")

        let zeroSize = NSSize(width: 0, height: 0)
        let zeroResized = delegate.windowWillResize(window, to: zeroSize)
        XCTAssertGreaterThan(zeroResized.width, 0, "Resized width must be positive for zero input")
        XCTAssertGreaterThan(zeroResized.height, 0, "Resized height must be positive for zero input")

        // 3. Aspect-preserved maximum safe content size calculations
        let screenSize = NSSize(width: 1920, height: 1080)

        // 16:9
        let max169 = PlayerGeometry.maximumSafeContentSize(for: 16.0 / 9.0, screenVisibleSize: screenSize)
        let ratio169 = max169.width / max169.height
        XCTAssertEqual(ratio169, 16.0 / 9.0, accuracy: 0.02, "16:9 maximum safe size must preserve aspect ratio")
        XCTAssertLessThanOrEqual(max169.width, screenSize.width * 0.88 + 1.0)
        XCTAssertLessThanOrEqual(max169.height, screenSize.height * 0.85 + 1.0)

        // 2.39:1 (Cinemascope)
        let maxCinemascope = PlayerGeometry.maximumSafeContentSize(for: 2.39, screenVisibleSize: screenSize)
        let ratioCinemascope = maxCinemascope.width / maxCinemascope.height
        XCTAssertEqual(ratioCinemascope, 2.39, accuracy: 0.02, "2.39:1 maximum safe size must preserve aspect ratio")
        XCTAssertLessThanOrEqual(maxCinemascope.width, screenSize.width * 0.88 + 1.0)
        XCTAssertLessThanOrEqual(maxCinemascope.height, screenSize.height * 0.85 + 1.0)

        // 9:16 (Vertical)
        let maxVertical = PlayerGeometry.maximumSafeContentSize(for: 9.0 / 16.0, screenVisibleSize: screenSize)
        let ratioVertical = maxVertical.width / maxVertical.height
        XCTAssertEqual(ratioVertical, 9.0 / 16.0, accuracy: 0.02, "9:16 maximum safe size must preserve aspect ratio")
        XCTAssertLessThanOrEqual(maxVertical.width, screenSize.width * 0.88 + 1.0)
        XCTAssertLessThanOrEqual(maxVertical.height, screenSize.height * 0.85 + 1.0)

        // 4. Aspect-preserved 100% maximized window content size calculations
        let full169 = PlayerGeometry.maximizedContentSize(for: 16.0 / 9.0, screenVisibleSize: screenSize)
        XCTAssertEqual(full169.width, 1920, "16:9 maximized size on 16:9 screen must fill full width")
        XCTAssertEqual(full169.height, 1080, "16:9 maximized size on 16:9 screen must fill full height")

        let ultrawideScreen = NSSize(width: 2752, height: 1027)
        let ultrawide169 = PlayerGeometry.maximizedContentSize(for: 16.0 / 9.0, screenVisibleSize: ultrawideScreen)
        XCTAssertEqual(ultrawide169.height, 1027, "16:9 on 21:9 screen must fill 100% visible height")
        XCTAssertEqual(ultrawide169.width, 1826, "16:9 on 21:9 screen must be 1826 width")

        let fullCinemascope = PlayerGeometry.maximizedContentSize(for: 2.39, screenVisibleSize: screenSize)
        XCTAssertEqual(fullCinemascope.width, 1920, "2.39:1 on 16:9 screen must fill 100% width")
        XCTAssertEqual(fullCinemascope.height, 803, "2.39:1 on 16:9 screen must be 803 height")
    }

    // MARK: - 5. Pin -> Resize -> Unpin -> Fullscreen Flow Invariant
    @MainActor
    func testPinResizeUnpinFullscreenFlow() {
        let player = PlayerCore()
        let session = PlayerWindowSession(id: UUID(), player: player)
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 150, width: 960, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let delegate = PlayerWindowDelegate(session: session, player: player)
        session.window = window
        session.windowDelegate = delegate
        window.delegate = delegate
        player.hostWindow = window
        PlayerWindowManager.shared.registerSession(session)
        defer { PlayerWindowManager.shared.unregisterSession(id: session.id) }

        window.collectionBehavior.insert([.fullScreenPrimary, .fullScreenAllowsTiling])

        // 1. 开启置顶：仅提升窗口层级为 .floating，严禁剥离全屏主能力集
        PlayerWindowManager.shared.isAlwaysOnTop = true
        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenPrimary))

        // 2. 模拟置顶下拉伸窗口
        let newSize = delegate.windowWillResize(window, to: NSSize(width: 1200, height: 675))
        window.setFrame(NSRect(origin: window.frame.origin, size: newSize), display: false)
        NotificationCenter.default.post(name: NSWindow.didEndLiveResizeNotification, object: window)
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenPrimary))

        // 3. 取消置顶：恢复 .normal 层级，严禁调用非法 order 或丢失能力集
        PlayerWindowManager.shared.isAlwaysOnTop = false
        XCTAssertEqual(window.level, .normal)
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenPrimary))

        // 4. 发起全屏请求
        player.toggleFullscreen()
        XCTAssertTrue(player.isFullscreenTransitioning)
    }

    // MARK: - 6. Window Scale Presets & Right-Click Context Menu Gating (Proposal 027)
    func testWindowPresetContentSizeAndBoundaryMenuGating() {
        let ultrawideScreen = NSSize(width: 2752, height: 1027)
        let aspect16x9: CGFloat = 16.0 / 9.0
        let min16x9 = PlayerGeometry.minimumContentSize(for: aspect16x9, screenVisibleHeight: ultrawideScreen.height)
        let max16x9 = PlayerGeometry.maximizedContentSize(for: aspect16x9, screenVisibleSize: ultrawideScreen)
        XCTAssertEqual(max16x9, NSSize(width: 1826, height: 1027))

        let p50 = PlayerGeometry.windowPresetContentSize(fraction: 0.5, aspect: aspect16x9, screenVisibleSize: ultrawideScreen)
        let p75 = PlayerGeometry.windowPresetContentSize(fraction: 0.75, aspect: aspect16x9, screenVisibleSize: ultrawideScreen)
        let p100 = PlayerGeometry.windowPresetContentSize(fraction: 1.0, aspect: aspect16x9, screenVisibleSize: ultrawideScreen)
        XCTAssertEqual(p50, NSSize(width: 913, height: 514))
        XCTAssertEqual(p75, NSSize(width: 1370, height: 771))
        XCTAssertEqual(p100, max16x9)
        XCTAssertGreaterThanOrEqual(p50.width, min16x9.width)

        // Portrait 9:16 fills vertical edges at 100%, halves cleanly to 50%, and locks enlargement at 100%
        let portraitAspect: CGFloat = 9.0 / 16.0
        let minPortrait = PlayerGeometry.minimumContentSize(for: portraitAspect, screenVisibleHeight: ultrawideScreen.height)
        let maxPortrait = PlayerGeometry.maximizedContentSize(for: portraitAspect, screenVisibleSize: ultrawideScreen)
        XCTAssertEqual(maxPortrait, NSSize(width: 578, height: 1027))

        let vp50 = PlayerGeometry.windowPresetContentSize(fraction: 0.5, aspect: portraitAspect, screenVisibleSize: ultrawideScreen)
        let vp75 = PlayerGeometry.windowPresetContentSize(fraction: 0.75, aspect: portraitAspect, screenVisibleSize: ultrawideScreen)
        let vp100 = PlayerGeometry.windowPresetContentSize(fraction: 1.0, aspect: portraitAspect, screenVisibleSize: ultrawideScreen)
        XCTAssertEqual(vp50, NSSize(width: 289, height: 514))
        XCTAssertEqual(vp75, NSSize(width: 433, height: 770))
        XCTAssertEqual(vp100, maxPortrait)

        // When vertical window is already flush against top/bottom edges (100%): 100% is disabled (cannot enlarge), 75% & 50% stay enabled
        let atEdge100 = PlayerGeometry.windowPresetMenuState(targetSize: vp100, currentSize: maxPortrait, minSize: minPortrait, maxSize: maxPortrait)
        let atEdge75 = PlayerGeometry.windowPresetMenuState(targetSize: vp75, currentSize: maxPortrait, minSize: minPortrait, maxSize: maxPortrait)
        let atEdge50 = PlayerGeometry.windowPresetMenuState(targetSize: vp50, currentSize: maxPortrait, minSize: minPortrait, maxSize: maxPortrait)
        XCTAssertEqual(atEdge100, .init(isEnabled: false, isCurrent: true))
        XCTAssertEqual(atEdge75, .init(isEnabled: true, isCurrent: false))
        XCTAssertEqual(atEdge50, .init(isEnabled: true, isCurrent: false))

        // After shrinking to 50%: 50% disables as current, while 75% and 100% unlock for scaling back up
        let at50State50 = PlayerGeometry.windowPresetMenuState(targetSize: vp50, currentSize: vp50, minSize: minPortrait, maxSize: maxPortrait)
        let at50State75 = PlayerGeometry.windowPresetMenuState(targetSize: vp75, currentSize: vp50, minSize: minPortrait, maxSize: maxPortrait)
        let at50State100 = PlayerGeometry.windowPresetMenuState(targetSize: vp100, currentSize: vp50, minSize: minPortrait, maxSize: maxPortrait)
        XCTAssertEqual(at50State50, .init(isEnabled: false, isCurrent: true))
        XCTAssertEqual(at50State75, .init(isEnabled: true, isCurrent: false))
        XCTAssertEqual(at50State100, .init(isEnabled: true, isCurrent: false))

        // Even 2.39:1 on 1512x900 clamps 50% cleanly to minimumContentSize without UI crush
        let macbookScreen = NSSize(width: 1512, height: 900)
        let wideMin = PlayerGeometry.minimumContentSize(for: 2.39, screenVisibleHeight: macbookScreen.height)
        let wideP50 = PlayerGeometry.windowPresetContentSize(fraction: 0.5, aspect: 2.39, screenVisibleSize: macbookScreen)
        XCTAssertEqual(wideP50, wideMin)
    }

    @MainActor
    func testFitWindowPercentageAndContextMenuStateGating() {
        let player = PlayerCore()
        let session = PlayerWindowSession(id: UUID(), player: player)
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 150, width: 1400, height: 788),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        let delegate = PlayerWindowDelegate(session: session, player: player)
        session.window = window
        session.windowDelegate = delegate
        window.delegate = delegate
        player.hostWindow = window
        PlayerWindowManager.shared.registerSession(session)
        defer { PlayerWindowManager.shared.unregisterSession(id: session.id) }

        player.isLoaded = true
        player.isAudioOnly = false
        player.videoWidth = 3840
        player.videoHeight = 2160
        player.displayVideoWidth = 3840
        player.displayVideoHeight = 2160

        let screenVisible = (window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)).size

        // Simulate locked large minSize + maximized mode before shrinking to 50%
        window.minSize = NSSize(width: 900, height: 506)
        window.contentMinSize = window.minSize
        delegate.toggleMaximize(window: window)
        XCTAssertEqual(delegate.currentInteractiveMode, .maximized)

        player.fitWindow(scale: 0.5)
        let expected50 = PlayerGeometry.windowPresetContentSize(
            fraction: 0.5,
            aspect: player.effectiveAspectRatio,
            screenVisibleSize: screenVisible
        )
        XCTAssertEqual(delegate.currentInteractiveMode, .normal)
        XCTAssertEqual(round(window.frame.width), expected50.width)
        XCTAssertEqual(round(window.frame.height), expected50.height)

        let containerView = MetalPlayerContainerView(playerCore: player)
        let menuAt50 = containerView.buildContextMenu(for: player)
        let submenuAt50 = menuAt50.items.first { $0.title == L10n.windowSizeMenu }?.submenu
        XCTAssertEqual(submenuAt50?.items.count, 5) // 50%, 75%, 100%, separator, Reset to Default
        XCTAssertEqual(submenuAt50?.items[0].title, "50%")
        XCTAssertEqual(submenuAt50?.items[1].title, "75%")
        XCTAssertEqual(submenuAt50?.items[2].title, "100%")
        XCTAssertEqual(submenuAt50?.items[4].title, L10n.windowSizeReset)
        XCTAssertEqual(submenuAt50?.items[0].state, .on)
        XCTAssertFalse(submenuAt50?.items[0].isEnabled ?? true)  // 50% current -> disabled
        XCTAssertTrue(submenuAt50?.items[1].isEnabled ?? false)  // 75% -> enabled
        XCTAssertTrue(submenuAt50?.items[2].isEnabled ?? false)  // 100% -> enabled

        // Programmatic scale > 1.0 clamps to 100% edge fit and locks 100% menu item
        player.fitWindow(scale: 2.0)
        let expected100 = PlayerGeometry.windowPresetContentSize(
            fraction: 1.0,
            aspect: player.effectiveAspectRatio,
            screenVisibleSize: screenVisible
        )
        XCTAssertEqual(round(window.frame.width), expected100.width)
        XCTAssertEqual(round(window.frame.height), expected100.height)

        let menuAt100 = containerView.buildContextMenu(for: player)
        let submenuAt100 = menuAt100.items.first { $0.title == L10n.windowSizeMenu }?.submenu
        XCTAssertTrue(submenuAt100?.items[0].isEnabled ?? false)  // 50% -> enabled
        XCTAssertTrue(submenuAt100?.items[1].isEnabled ?? false)  // 75% -> enabled
        XCTAssertEqual(submenuAt100?.items[2].state, .on)
        XCTAssertFalse(submenuAt100?.items[2].isEnabled ?? true)  // 100% at edge -> disabled

        // Reset to adaptive default even if autoResizeWindow is turned off
        let previousAutoResize = AppSettings.shared.autoResizeWindow
        AppSettings.shared.autoResizeWindow = false
        defer { AppSettings.shared.autoResizeWindow = previousAutoResize }

        player.resetWindowSize()
        let expectedAdaptive = PlayerGeometry.adaptiveVideoContentSize(
            for: player.effectiveAspectRatio,
            isVertical: false,
            rawVideoWidth: 3840,
            screenVisibleSize: screenVisible
        )
        XCTAssertEqual(round(window.frame.width), expectedAdaptive.width)
        XCTAssertEqual(round(window.frame.height), expectedAdaptive.height)

        let menuAtDefault = containerView.buildContextMenu(for: player)
        let resetItemAtDefault = menuAtDefault.items.first { $0.title == L10n.windowSizeMenu }?.submenu?.items.last
        XCTAssertEqual(resetItemAtDefault?.state, .on)
        XCTAssertFalse(resetItemAtDefault?.isEnabled ?? true)

        // Fullscreen mode blocks fitWindow and disables context menu scale submenu
        player.isFullscreen = true
        let frameBeforeFullscreenFit = window.frame
        player.fitWindow(scale: 0.5)
        XCTAssertEqual(window.frame, frameBeforeFullscreenFit)

        let fullscreenMenu = containerView.buildContextMenu(for: player)
        let fullscreenSizeItem = fullscreenMenu.items.first { $0.title == L10n.windowSizeMenu }
        XCTAssertNotNil(fullscreenSizeItem)
        XCTAssertFalse(fullscreenSizeItem?.isEnabled ?? true)
        for subItem in fullscreenSizeItem?.submenu?.items ?? [] where !subItem.isSeparatorItem {
            XCTAssertFalse(subItem.isEnabled)
        }
    }
}
