import XCTest
@testable import FitnessCoach

final class HealthKitServiceTests: XCTestCase {
    func testHealthKitServiceCanBeCreated() {
        let service = HealthKitService()

        XCTAssertNotNil(service)
    }
}
