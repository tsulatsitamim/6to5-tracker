import XCTest
@testable import TrackerCore

final class TrackerCoreTests: XCTestCase {
    func testVersion() {
        XCTAssertEqual(TrackerCore.version, "0.1.0")
    }
}
