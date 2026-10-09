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

    func testMixedLegacyScheduledTasksPreserveEveryFanTaskAndItsParameters() throws {
        let autoID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let constantID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let sensorID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        func task(_ action: String, id: UUID) -> [String: Any] {
            ["id": id.uuidString, "action": action, "repeatInterval": "daily",
             "startTime": 12345.0, "chargeLimit": 80, "fanSpeed": 3456,
             "sensorKey": "TC0P", "minTemp": 37, "maxTemp": 82, "isActive": false]
        }
        var retiredSensorTask = task("setFanSensorBased", id: sensorID)
        retiredSensorTask["sensorKey"] = "TB0T"
        let legacy: [String: Any] = [
            "weatherUseCelsius": true,
            "scheduledTasks": [
                task("setChargeLimit", id: autoID), task("setFanAuto", id: autoID),
                task("topUp", id: constantID), task("setFanConstant", id: constantID),
                task("dischargeTo", id: sensorID), task("setFanSensorBased", id: sensorID),
                task("startCalibration", id: autoID), retiredSensorTask
            ]
        ]
        let settings = try XCTUnwrap(SettingsPersistence.decodeFromDictionary(legacy))
        XCTAssertEqual(settings.scheduledTasks.map(\.action), [.setFanAuto, .setFanConstant, .setFanSensorBased])
        XCTAssertEqual(settings.scheduledTasks.map(\.id), [autoID, constantID, sensorID])
        for task in settings.scheduledTasks {
            XCTAssertEqual(task.repeatInterval, .daily)
            XCTAssertEqual(task.startTime, Date(timeIntervalSinceReferenceDate: 12345))
            XCTAssertEqual(task.fanSpeed, 3456)
            XCTAssertEqual(task.sensorKey, "TC0P")
            XCTAssertEqual(task.minTemp, 37)
            XCTAssertEqual(task.maxTemp, 82)
            XCTAssertFalse(task.isActive)
        }
        XCTAssertTrue(settings.weatherUseCelsius)
        let saved = try XCTUnwrap(SettingsPersistence.encodeToDictionary(settings))
        let savedTasks = try XCTUnwrap(saved["scheduledTasks"] as? [[String: Any]])
        XCTAssertTrue(savedTasks.allSatisfy { $0["chargeLimit"] == nil })
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

    func testLegacyBatterySensorsAreRetiredWithoutDiscardingOtherFanModes() throws {
        var legacy = try XCTUnwrap(SettingsPersistence.encodeToDictionary(Settings()))
        legacy["selectedSensorKeys"] = ["TC0P", "TB0T", "Tb0P", "IBAC", "PPBR", "TCHP", "Vb0R", "VD0R", "ID0R", "PDTR", "TG0P"]
        legacy["fanControlModes"] = [
            "0": ["kind": "sensor", "sensorKey": "TB0T", "minTemp": 40, "maxTemp": 75],
            "1": ["kind": "constant", "rpm": 3200],
            "2": ["kind": "customCurve", "sensorKey": "Tb0P", "points": [["temperature": 40, "rpm": 2000]]],
            "3": ["kind": "sensor", "sensorKey": "TC0P", "minTemp": 43, "maxTemp": 79]
        ] as [String: Any]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        let settings = try XCTUnwrap(SettingsPersistence.decodeFromPayload(data))
        XCTAssertEqual(settings.selectedSensorKeys, ["TC0P", "TG0P"])
        XCTAssertEqual(settings.fanControlModes.count, 4)
        XCTAssertEqual(settings.fanControlModes["0"]?.toMode(), .auto)
        XCTAssertEqual(settings.fanControlModes["1"]?.toMode(), .constant(rpm: 3200))
        XCTAssertEqual(settings.fanControlModes["2"]?.toMode(), .auto)
        XCTAssertEqual(settings.fanControlModes["3"]?.toMode(), .sensor(sensorKey: "TC0P", minTemp: 43, maxTemp: 79))
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
