import CoreServices
import XCTest
@testable import Sapphire

final class PermissionsManagerTests: XCTestCase {
    func testAutomationOSStatusMapsOnlyExplicitRefusalToDenied() {
        XCTAssertEqual(PermissionsManager.automationPermissionStatus(for: OSStatus(noErr)), .granted)
        XCTAssertEqual(PermissionsManager.automationPermissionStatus(for: OSStatus(errAEEventNotPermitted)), .denied)
        XCTAssertEqual(PermissionsManager.automationPermissionStatus(for: OSStatus(errAETargetAddressNotPermitted)), .denied)
        XCTAssertEqual(PermissionsManager.automationPermissionStatus(for: OSStatus(errAEEventWouldRequireUserConsent)), .notRequested)
        XCTAssertEqual(PermissionsManager.automationPermissionStatus(for: OSStatus(procNotFound)), .notRequested)
        XCTAssertEqual(PermissionsManager.automationPermissionStatus(for: OSStatus(paramErr)), .notRequested)
    }

    func testAutomationAggregateDeniedWinsAndGrantedRequiresAllTargets() {
        XCTAssertEqual(PermissionsManager.aggregateAutomationStatus([]), .notRequested)
        XCTAssertEqual(PermissionsManager.aggregateAutomationStatus([.granted]), .granted)
        XCTAssertEqual(PermissionsManager.aggregateAutomationStatus([.granted, .granted]), .granted)
        XCTAssertEqual(PermissionsManager.aggregateAutomationStatus([.granted, .notRequested]), .notRequested)
        XCTAssertEqual(PermissionsManager.aggregateAutomationStatus([.notRequested, .denied]), .denied)
        XCTAssertEqual(PermissionsManager.aggregateAutomationStatus([.granted, .denied]), .denied)
    }
}
