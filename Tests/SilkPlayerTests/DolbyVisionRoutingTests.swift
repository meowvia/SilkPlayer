import XCTest
import Foundation
@testable import SilkPlayer
import SilkCoreKit

final class DolbyVisionRoutingTests: XCTestCase {

    // Helper calling the exact production SilkColorArbitration.resolve function
    private func simulateDemux(
        profile: Int,
        compatId: Int,
        trc: UInt32,
        space: UInt32,
        primaries: UInt32,
        range: UInt32
    ) -> SilkColorRoutingResult {
        SilkColorArbitration.resolve(
            profile: profile,
            doviCompatId: compatId,
            trc: trc,
            space: space,
            primaries: primaries,
            range: range
        )
    }

    // 1. BT.2020 广色域 SDR 防误判断言（绝不因 color_space 触发 PQ）
    func testBT2020SDRMustNotTriggerHDR10() {
        let result = simulateDemux(
            profile: 0,
            compatId: 0,
            trc: SilkColorArbitration.AVCOL_TRC_BT709,
            space: SilkColorArbitration.AVCOL_SPC_BT2020_NCL,
            primaries: SilkColorArbitration.AVCOL_PRI_BT2020,
            range: SilkColorArbitration.AVCOL_RANGE_MPEG
        )
        XCTAssertFalse(result.isHDR10, "BT.2020 广色域 SDR 严禁因 color_space 触发 HDR10 PQ 管线")
        XCTAssertFalse(result.isHLG, "SDR 片源不应标记为 HLG")
        XCTAssertEqual(result.pipeline, .sdr, "必须正确归入 SDR 管线")
        XCTAssertEqual(result.osdBadge, "SDR (BT.709)")
    }

    // 2. 纯 HLG 广播流判定断言
    func testPureHLGBroadcastStreamRouting() {
        let result = simulateDemux(
            profile: 0,
            compatId: 0,
            trc: SilkColorArbitration.AVCOL_TRC_ARIB_STD_B67,
            space: SilkColorArbitration.AVCOL_SPC_BT2020_NCL,
            primaries: SilkColorArbitration.AVCOL_PRI_BT2020,
            range: SilkColorArbitration.AVCOL_RANGE_MPEG
        )
        XCTAssertTrue(result.isHLG, "纯 HLG 广播流必须命中 HLG 管线")
        XCTAssertFalse(result.isHDR10, "HLG 不得被当作 HDR10 PQ 处理")
        XCTAssertEqual(result.pipeline, .hlg, "管线必须指向 .hlg")
        XCTAssertEqual(result.osdBadge, "HLG (BT.2020)")
    }

    // 3. Profile 8.2 SDR 显式降级断言（防过曝死白关键防线）
    func testProfile82ExplicitSDRFallback() {
        let result = simulateDemux(
            profile: 8,
            compatId: 2,
            trc: SilkColorArbitration.AVCOL_TRC_BT709,
            space: SilkColorArbitration.AVCOL_SPC_BT709,
            primaries: SilkColorArbitration.AVCOL_PRI_BT709,
            range: SilkColorArbitration.AVCOL_RANGE_MPEG
        )
        XCTAssertFalse(result.isHDR10, "Profile 8.2 (BT.709 基础层) 必须显式拦截 HDR10")
        XCTAssertFalse(result.isHLG, "Profile 8.2 不是 HLG")
        XCTAssertEqual(result.pipeline, .sdr, "必须降级至 SDR 管线以防过曝")
        XCTAssertEqual(result.osdBadge, "Dolby Vision Profile 8.2 (SDR)")
    }

    // 4. Profile 5 非法伪装防御断言
    func testProfile5FalseBT709TamperProtection() {
        let result = simulateDemux(
            profile: 5,
            compatId: 0,
            trc: SilkColorArbitration.AVCOL_TRC_BT709,
            space: SilkColorArbitration.AVCOL_SPC_BT709,
            primaries: SilkColorArbitration.AVCOL_PRI_BT709,
            range: SilkColorArbitration.AVCOL_RANGE_MPEG
        )
        XCTAssertEqual(result.dolbyVisionProfile, 0, "Profile 5 携带 BT.709 标头必须剔除杜比标记")
        XCTAssertFalse(result.isHDR10)
        XCTAssertFalse(result.isHLG)
        XCTAssertEqual(result.pipeline, .sdr, "回退至标准 SDR")
    }

    // 5. Profile 8.4 HLG 路由与 Full Range 量化标定断言 (iPhone 直出测试)
    func testProfile84HLGRoutingAndFullRange() {
        let result = simulateDemux(
            profile: 8,
            compatId: 4,
            trc: SilkColorArbitration.AVCOL_TRC_ARIB_STD_B67,
            space: SilkColorArbitration.AVCOL_SPC_BT2020_NCL,
            primaries: SilkColorArbitration.AVCOL_PRI_BT2020,
            range: SilkColorArbitration.AVCOL_RANGE_JPEG
        )
        XCTAssertTrue(result.isHLG, "Profile 8.4 必须命中 HLG")
        XCTAssertTrue(result.isDoviProfile84)
        XCTAssertTrue(result.isFullRange, "JPEG 范围必须正确标记 Full Range")
        XCTAssertEqual(result.pipeline, .hlg)
        XCTAssertEqual(result.osdBadge, "Dolby Vision Profile 8.4 (HLG)")
    }

    // 6. Profile 8.1 HDR10 路由断言
    func testProfile81HDR10Routing() {
        let result = simulateDemux(
            profile: 8,
            compatId: 1,
            trc: SilkColorArbitration.AVCOL_TRC_SMPTE2084,
            space: SilkColorArbitration.AVCOL_SPC_BT2020_NCL,
            primaries: SilkColorArbitration.AVCOL_PRI_BT2020,
            range: SilkColorArbitration.AVCOL_RANGE_MPEG
        )
        XCTAssertTrue(result.isHDR10, "Profile 8.1 必须命中 HDR10 PQ 管线")
        XCTAssertFalse(result.isHLG)
        XCTAssertEqual(result.pipeline, .hdr10)
        XCTAssertEqual(result.osdBadge, "Dolby Vision Profile 8.1 (HDR10)")
    }
}
