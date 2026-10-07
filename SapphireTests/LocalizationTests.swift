import Foundation
import XCTest
@testable import Sapphire

final class LocalizationTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "Sapphire.LocalizationTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSwitchingLanguageReplacesThePreviousNativeOverride() {
        AppLanguage.english.apply(to: defaults)
        AppLanguage.simplifiedChinese.apply(to: defaults)
        XCTAssertEqual(preferredResourceLanguage(), "zh-Hans")

        AppLanguage.english.apply(to: defaults)
        XCTAssertEqual(preferredResourceLanguage(), "en")
        XCTAssertEqual(defaults.stringArray(forKey: "AppleLanguages"), ["en"])
    }

    func testFollowingSystemRemovesOnlyTheAppLanguageOverride() {
        defaults.set("de_DE", forKey: "AppleLocale")
        defaults.set(Data([1, 2, 3]), forKey: "sapphire.settings.payload")
        AppLanguage.simplifiedChinese.apply(to: defaults)
        AppLanguage.system.apply(to: defaults)

        XCTAssertNil(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"])
        XCTAssertEqual(defaults.string(forKey: "AppleLocale"), "de_DE")
        XCTAssertEqual(defaults.data(forKey: "sapphire.settings.payload"), Data([1, 2, 3]))
    }

    func testRestoredLegacyChineseChoicesStillSelectChineseResources() {
        for storedValue in ["zh", "zh-CN", "zh_CN", "zh-Hans"] {
            AppLanguage(storedValue: storedValue).apply(to: defaults)
            XCTAssertEqual(preferredResourceLanguage(), "zh-Hans", storedValue)
        }
    }

    func testUnsupportedStoredLanguageFollowsSystemInsteadOfKeepingAnOldOverride() {
        AppLanguage.english.apply(to: defaults)
        AppLanguage(storedValue: "unsupported-language").apply(to: defaults)
        XCTAssertNil(defaults.persistentDomain(forName: suiteName)?["AppleLanguages"])
    }

    private func preferredResourceLanguage() -> String? {
        Bundle.preferredLocalizations(
            from: ["en", "zh-Hans"],
            forPreferences: defaults.stringArray(forKey: "AppleLanguages")
        ).first
    }
}
