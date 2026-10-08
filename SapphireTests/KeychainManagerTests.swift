import Foundation
import XCTest
@testable import Sapphire

final class KeychainManagerTests: XCTestCase {
    func testPasswordPresenceTracksStoredAndDeletedCredential() {
        let manager = KeychainManager.shared
        let account = "SapphirePresenceTest-\(UUID().uuidString)"
        let otherAccount = "SapphirePresenceTest-\(UUID().uuidString)"
        let payload = Data("isolated-test-credential".utf8)
        defer { _ = manager.delete(for: account) }

        XCTAssertFalse(manager.contains(for: account))
        XCTAssertTrue(manager.save(key: payload, for: account))
        XCTAssertTrue(manager.contains(for: account))
        XCTAssertFalse(manager.contains(for: otherAccount))
        XCTAssertEqual(manager.load(for: account), payload)
        XCTAssertTrue(manager.delete(for: account))
        XCTAssertFalse(manager.contains(for: account))
    }
}
