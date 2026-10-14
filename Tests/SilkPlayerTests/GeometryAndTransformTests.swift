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
}
