//
//  MediaApplicationIdentity.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-13

enum MediaApplicationIdentity {
    static func canonicalBundleID(_ bundleID: String?) -> String? {
        guard let bundleID else { return nil }
        switch bundleID {
        case "com.apple.WebKit.GPU", "com.apple.WebKit.WebContent":
            return "com.apple.Safari"
        case let id where id.starts(with: "com.google.Chrome.helper"):
            return "com.google.Chrome"
        case let id where id.starts(with: "com.microsoft.edgemac.helper"):
            return "com.microsoft.edgemac"
        case "company.thebrowser.Browser.helper":
            return "company.thebrowser.Browser"
        default:
            return bundleID
        }
    }
}

enum MusicContentSource: Hashable {
    case system, spotify, appleMusic

    static func resolve(
        bundleIdentifier: String?,
        spotifySelected: Bool,
        phoneSelected: Bool
    ) -> MusicContentSource {
        guard !phoneSelected else { return .system }
        if spotifySelected { return .spotify }
        if bundleIdentifier == "com.apple.Music" { return .appleMusic }
        return .system
    }

    var supportsLibrary: Bool { self != .system }

    func requiresSpotifyLogin(authenticated: Bool) -> Bool {
        self == .spotify && !authenticated
    }
}