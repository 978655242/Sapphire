//
//  PremiumFeatureModels.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import AppKit
import Combine
import Foundation

enum CaretPositionTracker {
    struct CaretInfo {
        let anchorPoint: NSPoint
        let lineNumber: Int?
        let isExact: Bool
    }

    static func caretInfo() -> CaretInfo? { nil }
    static func anchorPoint() -> NSPoint? { nil }
}

@MainActor
final class WiFiStatusMonitor: ObservableObject {
    struct State: Equatable {
        var isConnected = false
        var networkName: String?
        var isInterfacePowerOn = false
    }

    static let shared = WiFiStatusMonitor()
    @Published private(set) var state = State()

    private init() {}
    func startPolling() {}
    func stopPolling() {}
    func refresh(completion: (() -> Void)? = nil) { completion?() }
}


struct DockLayout: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = "New Preset".local
}

struct SnippetEntry: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var trigger: String = ""
    var replacement: String = ""
    var isEnabled: Bool = true
}

enum EmojiSkinTone: String, Codable, CaseIterable, Identifiable {
    case none, light, mediumLight, medium, mediumDark, dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "Default".local
        case .light: "Light".local
        case .mediumLight: "Medium Light".local
        case .medium: "Medium".local
        case .mediumDark: "Medium Dark".local
        case .dark: "Dark".local
        }
    }
}

enum MouseButtonAction: String, Codable, CaseIterable, Identifiable {
    case none, back, forward, copy, paste, cut, undo, redo, selectAll
    case missionControl, launchpad, showDesktop, appSwitcher, spotlight
    case closeWindow, minimize, newTab, newWindow, reload, fullScreen
    case lockScreen, openSapphireSettings

    var id: String { rawValue }
}

struct MouseModifierSelection: Codable, Equatable {
    var rawValue: UInt

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    init(flags: NSEvent.ModifierFlags) {
        rawValue = flags.intersection([.control, .option, .command, .shift]).rawValue
    }

    var flags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: rawValue)
            .intersection([.control, .option, .command, .shift])
    }

    static let control = MouseModifierSelection(flags: .control)
    static let `default` = MouseModifierSelection(flags: .control)
}

enum SEQuitProtectionMode: String, CaseIterable, Identifiable {
    case hold, doublePress, extraModifier
    var id: String { rawValue }
}

enum SEQuitProtectionExtraModifier: String, CaseIterable, Identifiable {
    case option, control, shift
    var id: String { rawValue }
}

enum SEDockClickAction: String, CaseIterable, Identifiable {
    case minimize, hide, cycle
    var id: String { rawValue }
}

enum SESuperKeyKey: String, CaseIterable, Identifiable {
    case rightCommand, leftCommand, capsLock
    var id: String { rawValue }
}

enum SESuperKeyCombo: String, CaseIterable, Identifiable {
    case hyper
    var id: String { rawValue }
}

enum SESuperKeyTapAction: String, CaseIterable, Identifiable {
    case none
    var id: String { rawValue }
}

enum SEPreviewLayout: String {
    case grid, list, carousel
}

enum SEPreviewTrigger: String {
    case hover, middleClick, modifierClick
}

enum SESwitcherActivation: String {
    case command, option, both
}

extension Settings {
    var systemEnhancePreviewLayout: SEPreviewLayout {
        get { SEPreviewLayout(rawValue: systemEnhancePreviewLayoutRaw) ?? .grid }
        set { systemEnhancePreviewLayoutRaw = newValue.rawValue }
    }

    var systemEnhanceWindowSwitcherLayout: SEPreviewLayout {
        get { SEPreviewLayout(rawValue: systemEnhanceWindowSwitcherLayoutRaw) ?? .grid }
        set { systemEnhanceWindowSwitcherLayoutRaw = newValue.rawValue }
    }

    var systemEnhancePreviewTrigger: SEPreviewTrigger {
        get { SEPreviewTrigger(rawValue: systemEnhancePreviewTriggerRaw) ?? .hover }
        set { systemEnhancePreviewTriggerRaw = newValue.rawValue }
    }

    var systemEnhanceSwitcherActivation: SESwitcherActivation {
        get { SESwitcherActivation(rawValue: systemEnhanceSwitcherActivationRaw) ?? .both }
        set { systemEnhanceSwitcherActivationRaw = newValue.rawValue }
    }

    var systemEnhanceQuitProtectionMode: SEQuitProtectionMode {
        get { SEQuitProtectionMode(rawValue: systemEnhanceQuitProtectionModeRaw) ?? .hold }
        set { systemEnhanceQuitProtectionModeRaw = newValue.rawValue }
    }

    var systemEnhanceQuitProtectionExtraModifier: SEQuitProtectionExtraModifier {
        get { SEQuitProtectionExtraModifier(rawValue: systemEnhanceQuitProtectionExtraModifierRaw) ?? .option }
        set { systemEnhanceQuitProtectionExtraModifierRaw = newValue.rawValue }
    }

    var systemEnhanceDockClickAction: SEDockClickAction {
        get { SEDockClickAction(rawValue: systemEnhanceDockClickActionRaw) ?? .minimize }
        set { systemEnhanceDockClickActionRaw = newValue.rawValue }
    }

    var superKeyKey: SESuperKeyKey {
        get { SESuperKeyKey(rawValue: superKeyKeyRaw) ?? .rightCommand }
        set { superKeyKeyRaw = newValue.rawValue }
    }

    var superKeyCombo: SESuperKeyCombo {
        get { SESuperKeyCombo(rawValue: superKeyComboRaw) ?? .hyper }
        set { superKeyComboRaw = newValue.rawValue }
    }

    var superKeyTapAction: SESuperKeyTapAction {
        get { SESuperKeyTapAction(rawValue: superKeyTapActionRaw) ?? .none }
        set { superKeyTapActionRaw = newValue.rawValue }
    }
}

enum MenuBarRevealConditionKind: String, Codable, CaseIterable, Identifiable {
    case focusActive, focusIdentifier, wifiEquals, wifiConnected
    case scriptSucceeds, scriptFails, scriptExitCode

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .focusActive: "Any Focus Active".local
        case .focusIdentifier: "Focus Mode Is".local
        case .wifiEquals: "Wi-Fi Network Is".local
        case .wifiConnected: "Wi-Fi Connected".local
        case .scriptSucceeds: "Script Exits Successfully".local
        case .scriptFails: "Script Fails".local
        case .scriptExitCode: "Script Exit Code Is".local
        }
    }

    var systemImage: String {
        switch self {
        case .focusActive, .focusIdentifier: "moon.fill"
        case .wifiEquals, .wifiConnected: "wifi"
        case .scriptSucceeds, .scriptFails, .scriptExitCode: "terminal"
        }
    }
}

struct MenuBarRevealCondition: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var kind: MenuBarRevealConditionKind = .focusActive
    var focusIdentifier = ""
    var wifiNetworkName = ""
    var scriptPath = ""
    var scriptArgument = ""
    var scriptExitCode = 0
    var scriptPollInterval: TimeInterval = 30

    init() {}

    init(kind: MenuBarRevealConditionKind) {
        self.kind = kind
    }
}

enum MenuBarProfileDisplayScope: String, Codable, CaseIterable {
    case allDisplays, selectedDisplays
}

struct MenuBarDisplayBinding: Codable, Equatable, Identifiable, Hashable {
    var id: String { displayIdentifier }
    var displayIdentifier: String
    var displayLabel = ""
}

struct MenuBarProfile: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name = "New Profile".local
    var symbolName = "menubar.rectangle"
    var revealConditions: [MenuBarRevealCondition] = []
    var isEnabled = true
    var bindsToDisplays = false
    var displayScope: MenuBarProfileDisplayScope = .selectedDisplays
    var displayBindings: [MenuBarDisplayBinding] = []
    var bindsToSpaces = false
    var spaceNumbers: [Int] = []
    var bindsToFocus = false
    var focusIdentifiers: [String] = []

    init() {}

    init(name: String) {
        self.name = name
    }

    var summaryText: String {
        revealConditions.isEmpty ? "No conditions".local : String(localized: "\(revealConditions.count) condition(s)")
    }
}

final class MenuBarProfileEngine {
    struct FocusModeOption: Identifiable, Sendable {
        let identifier: String
        let name: String
        let symbolName: String

        var id: String { identifier }
    }

    static let shared = MenuBarProfileEngine()

    private(set) var isRevealRequested = false

    private init() {}

    func start() {}
    func stop() {}
    func refresh() {}

    static func fetchAvailableFocusModes() -> [FocusModeOption] { [] }
}

extension Notification.Name {
    static let menuBarProfilesDidChange = Notification.Name("com.sapphire.menuBarProfilesDidChange")
}
#endif