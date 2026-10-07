import Foundation

/// App-scoped Apple language preferences are read by SwiftUI, AppKit and system
/// permission prompts on launch. Restarting avoids mixed-language cached UI.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }

    init(storedValue: String) {
        switch storedValue {
        case "en": self = .english
        case "zh", "zh-CN", "zh_CN", "zh-Hans": self = .simplifiedChinese
        default: self = .system
        }
    }

    var displayName: String {
        switch self {
        case .system: return "Follow System".local
        case .english: return "English"
        case .simplifiedChinese: return "简体中文"
        }
    }

    func apply(to defaults: UserDefaults = .standard) {
        switch self {
        case .system:
            defaults.removeObject(forKey: "AppleLanguages")
        case .english:
            defaults.set(["en"], forKey: "AppleLanguages")
        case .simplifiedChinese:
            defaults.set(["zh-Hans", "en"], forKey: "AppleLanguages")
        }
    }
}

enum AppLocalization {
    /// Resource language, rather than the machine's locale, controls display
    /// formatters. Protocol and persistence parsers keep their explicit locale.
    static let locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")

    /// Privileged helper errors carry resource keys separately from diagnostic
    /// text so the unbundled helper never needs to choose the user's language.
    static func description(for error: Error) -> String {
        let error = error as NSError
        guard let key = error.userInfo["SapphireLocalizationKey"] as? String else {
            return error.localizedDescription
        }
        let arguments = error.userInfo["SapphireLocalizationArguments"] as? [String] ?? []
        return String(format: key.local, locale: locale, arguments: arguments.map { $0 as CVarArg })
    }
}

extension String {
    /// Only app-owned display keys belong here; identifiers and user content
    /// stay verbatim. Interpolated messages use String(localized:) instead.
    var local: String { NSLocalizedString(self, comment: "") }
}
