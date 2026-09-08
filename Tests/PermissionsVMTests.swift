import XCTest
@testable import Input_Source_Pro

@MainActor
final class PermissionsVMTests: XCTestCase {
    func testRefreshDetectsRevocationAndRegrant() {
        var accessibilityGranted = true
        var inputMonitoringGranted = true
        let permissions = PermissionsVM(
            accessibilityCheck: { accessibilityGranted },
            inputMonitoringCheck: { inputMonitoringGranted }
        )

        accessibilityGranted = false
        inputMonitoringGranted = false
        permissions.refresh()

        XCTAssertFalse(permissions.isAccessibilityEnabled)
        XCTAssertFalse(permissions.isInputMonitoringEnabled)

        accessibilityGranted = true
        inputMonitoringGranted = true
        permissions.refresh()

        XCTAssertTrue(permissions.isAccessibilityEnabled)
        XCTAssertTrue(permissions.isInputMonitoringEnabled)
    }

    func testRefreshTracksPermissionsIndependently() {
        var accessibilityGranted = true
        var inputMonitoringGranted = false
        let permissions = PermissionsVM(
            accessibilityCheck: { accessibilityGranted },
            inputMonitoringCheck: { inputMonitoringGranted }
        )

        accessibilityGranted = false
        inputMonitoringGranted = true
        permissions.refresh()

        XCTAssertFalse(permissions.isAccessibilityEnabled)
        XCTAssertTrue(permissions.isInputMonitoringEnabled)
    }
}
