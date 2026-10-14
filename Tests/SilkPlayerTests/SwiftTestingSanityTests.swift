import Testing

@Suite("SwiftTestingSanityTests")
struct SwiftTestingSanityTests {
    @Test("Verify Swift Testing Runner Baseline")
    func testSanity() {
        #expect(true)
    }
}
