import XCTest
@testable import Sapphire

final class BatterySettingsMigrationTests: XCTestCase {
    func testLegacyPayloadKeepsSurvivingOrdersAndUnrelatedPreferences() throws {
        var legacy = try XCTUnwrap(SettingsPersistence.encodeToDictionary(Settings()))
        legacy["widgetOrder"] = ["notes", "battery", "music", "weather"]
        legacy["notchButtonOrder"] = ["pin", "battery", "settings", "spacer"]
        legacy["liveActivityOrder"] = ["weather", "battery", "music"]
        legacy["lockScreenWidgets"] = ["bluetooth", "battery", "weather"]
        legacy["lockScreenMainWidgets"] = ["notes", "battery", "music"]
        legacy["lockScreenMiniWidgets"] = ["timer", "battery", "clipboard"]
        legacy["selectedStats"] = ["systemPower", "batteryPower", "cpu"]
        legacy["statThresholds"] = [
            "batteryPower", ["isEnabled": true, "value": 25],
            "cpu", ["isEnabled": true, "value": 93],
            "systemPower", ["isEnabled": false, "value": 41]
        ] as [Any]
        legacy["hideActivitiesInFullScreen"] = ["battery": true, "music": true, "weather": false]
        legacy["batteryChargeLimit"] = 70
        legacy["liveWallpaperPauseOnBattery"] = true
        legacy["appLanguage"] = "zh-Hans"
        legacy["weatherUseCelsius"] = true
        legacy["focusSessionDuration"] = 4321.0
        legacy["desktopWallpaperPath"] = "/Users/example/wallpaper.mov"
        legacy["bluetoothNotifySound"] = false

        let data = try JSONSerialization.data(withJSONObject: legacy)
        let settings = try XCTUnwrap(SettingsPersistence.decodeFromPayload(data))
        XCTAssertEqual(Array(settings.widgetOrder.prefix(3)), [.notes, .music, .weather])
        XCTAssertEqual(Array(settings.notchButtonOrder.filter { [.pin, .settings, .spacer].contains($0) }), [.pin, .settings, .spacer])
        XCTAssertEqual(Array(settings.liveActivityOrder.prefix(2)), [.weather, .music])
        XCTAssertEqual(settings.lockScreenWidgets, [.bluetooth, .weather])
        XCTAssertEqual(settings.lockScreenMainWidgets, [.notes, .music])
        XCTAssertEqual(settings.lockScreenMiniWidgets, [.timer, .clipboard])
        XCTAssertEqual(settings.selectedStats, [.systemPower, .cpu])
        XCTAssertEqual(settings.statThresholds[.cpu], StatThreshold(isEnabled: true, value: 93))
        XCTAssertEqual(settings.statThresholds[.systemPower], StatThreshold(isEnabled: false, value: 41))
        XCTAssertEqual(settings.statThresholds.count, 2)
        XCTAssertEqual(settings.hideActivitiesInFullScreen, ["music": true, "weather": false])
        XCTAssertEqual(settings.appLanguage, "zh-Hans")
        XCTAssertTrue(settings.weatherUseCelsius)
        XCTAssertEqual(settings.focusSessionDuration, 4321)
        XCTAssertEqual(settings.desktopWallpaperPath, "/Users/example/wallpaper.mov")
        XCTAssertFalse(settings.bluetoothNotifySound)
        let saved = try XCTUnwrap(SettingsPersistence.encodeToDictionary(settings))
        XCTAssertNil(saved["batteryChargeLimit"])
        XCTAssertNil(saved["liveWallpaperPauseOnBattery"])
    }

    func testRetiredScalarSelectionsUseConventionalDefaultsWithoutResettingOtherSettings() throws {
        let legacy: [String: Any] = [
            "lockScreenWidgets": "battery", "lockScreenMainWidgets": "battery",
            "lockScreenMiniWidgets": "battery", "selectedStats": "batteryPower",
            "musicWidgetEnabled": false, "expandOnHoverDelay": 1.75
        ]
        let data = try JSONSerialization.data(withJSONObject: ["settings": legacy])
        let settings = try XCTUnwrap(SettingsPersistence.decodeFromPayload(data))
        XCTAssertEqual(settings.lockScreenWidgets, [.weather, .bluetooth])
        XCTAssertEqual(settings.lockScreenMainWidgets, [.weather])
        XCTAssertEqual(settings.lockScreenMiniWidgets, [.music])
        XCTAssertEqual(settings.selectedStats, [.cpu, .ram, .gpu, .disk])
        XCTAssertFalse(settings.musicWidgetEnabled)
        XCTAssertEqual(settings.expandOnHoverDelay, 1.75)
    }

    func testRemovingOnlyBatteryEntriesDoesNotReenableEmptyLockScreenSelections() throws {
        let settings = try XCTUnwrap(SettingsPersistence.decodeFromDictionary([
            "lockScreenWidgets": ["battery"], "lockScreenMainWidgets": ["battery"],
            "lockScreenMiniWidgets": ["battery"], "selectedStats": ["batteryPower"]
        ]))
        XCTAssertTrue(settings.lockScreenWidgets.isEmpty)
        XCTAssertTrue(settings.lockScreenMainWidgets.isEmpty)
        XCTAssertTrue(settings.lockScreenMiniWidgets.isEmpty)
        XCTAssertTrue(settings.selectedStats.isEmpty)
    }

    func testLegacyBatterySensorsAreRetiredWithoutDiscardingOtherSensors() throws {
        var legacy = try XCTUnwrap(SettingsPersistence.encodeToDictionary(Settings()))
        legacy["selectedSensorKeys"] = ["TC0P", "TB0T", "Tb0P", "IBAC", "PPBR", "TCHP", "Vb0R", "VD0R", "ID0R", "PDTR", "TG0P"]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let settings = try XCTUnwrap(SettingsPersistence.decodeFromPayload(data))
        XCTAssertEqual(settings.selectedSensorKeys, ["TC0P", "TG0P"])
    }

    func testBackupImportMigratesBatterySensorsEvenWhenThePayloadStillDecodes() throws {
        var settings = Settings()
        settings.selectedSensorKeys = ["TC0P", "TB0T"]
        settings.weatherUseCelsius = true
        let exportDate = Date(timeIntervalSinceReferenceDate: 12345)
        let data = try JSONEncoder().encode(SettingsBackupPayload(settings: settings, exportedAt: exportDate))
        let imported = try SettingsBackupDocument.decodePayload(from: data)
        XCTAssertEqual(imported.settings.selectedSensorKeys, ["TC0P"])
        XCTAssertTrue(imported.settings.weatherUseCelsius)
        XCTAssertEqual(imported.exportedAt, exportDate)
    }

    func testRetiredMenuConditionsDoNotDiscardProfileBindingsOrSurvivingRules() throws {
        var profile = MenuBarProfile(name: "Work")
        profile.id = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
        profile.symbolName = "briefcase"
        profile.isEnabled = false
        profile.bindsToSpaces = true
        profile.spaceNumbers = [2, 4]
        var wifi = MenuBarRevealCondition(kind: .wifiEquals)
        wifi.id = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
        wifi.wifiNetworkName = "Office"
        var focus = MenuBarRevealCondition(kind: .focusActive)
        focus.id = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        profile.revealConditions = [wifi, focus]
        var settings = Settings()
        settings.menuBarProfiles = [profile]
        settings.expandOnHoverDelay = 1.25
        var legacy = try XCTUnwrap(SettingsPersistence.encodeToDictionary(settings))
        var profiles = try XCTUnwrap(legacy["menuBarProfiles"] as? [[String: Any]])
        let conditions = try XCTUnwrap(profiles[0]["revealConditions"] as? [[String: Any]])
        let retiredConditions = ["batteryBelow", "batteryAbove", "charging", "onBatteryPower"].map { kind in
            var retired = conditions[0]
            retired["kind"] = kind
            retired["batteryThreshold"] = 20
            return retired
        }
        profiles[0]["revealConditions"] = [retiredConditions[0], conditions[0]]
            + Array(retiredConditions.dropFirst()) + [conditions[1]]
        legacy["menuBarProfiles"] = profiles
        let migrated = try XCTUnwrap(SettingsPersistence.decodeFromDictionary(legacy))
        let savedProfile = try XCTUnwrap(migrated.menuBarProfiles.first)
        XCTAssertEqual(savedProfile.id, profile.id)
        XCTAssertEqual(savedProfile.name, "Work")
        XCTAssertEqual(savedProfile.symbolName, "briefcase")
        XCTAssertFalse(savedProfile.isEnabled)
        XCTAssertTrue(savedProfile.bindsToSpaces)
        XCTAssertEqual(savedProfile.spaceNumbers, [2, 4])
        XCTAssertEqual(savedProfile.revealConditions.map(\.kind), [.wifiEquals, .focusActive])
        XCTAssertEqual(savedProfile.revealConditions.map(\.id), [wifi.id, focus.id])
        XCTAssertEqual(savedProfile.revealConditions.first?.wifiNetworkName, "Office")
        XCTAssertEqual(migrated.expandOnHoverDelay, 1.25)
    }

}
