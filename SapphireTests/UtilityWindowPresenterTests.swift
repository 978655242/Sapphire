import AppKit
import XCTest
@testable import Sapphire

final class UtilityWindowPresenterTests: XCTestCase {
    @MainActor
    func testOpeningAndClosingUtilityWindowsKeepsBackgroundApplicationIdentity() async {
        let app = NSApplication.shared
        let originalPolicy = app.activationPolicy()
        defer { app.setActivationPolicy(originalPolicy) }

        for present in [UtilityWindowPresenter.presentSettingsWindow, UtilityWindowPresenter.present] {
            app.setActivationPolicy(.accessory)
            let window = KeyableWindow(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            defer { window.close() }

            present(window)
            let visible = XCTNSPredicateExpectation(
                predicate: NSPredicate { _, _ in window.isVisible },
                object: window
            )
            await fulfillment(of: [visible], timeout: 3)
            XCTAssertEqual(app.activationPolicy(), .accessory)

            window.performClose(nil)
            XCTAssertFalse(window.isVisible)
            XCTAssertEqual(app.activationPolicy(), .accessory)
        }
    }
}
