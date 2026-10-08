//
//  AppSecurity.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import Foundation
import Security

struct AppCodeSignatureIdentity: Equatable {
    let signingIdentifier: String
    let teamIdentifier: String?
    let bundleIdentifier: String
}

enum AppSecurityValidationError: LocalizedError {
    case notAnApplication
    case bundleIdentifierMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .notAnApplication:
            NSLocalizedString("The downloaded item is not a valid application bundle.", comment: "")
        case .bundleIdentifierMismatch(let expected, let actual):
            String(localized: "The update is for \(actual), not \(expected).")
        }
    }
}

enum AppSecurityValidator {
    private static let validationFlags = SecCSFlags(
        rawValue: UInt32(kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate)
    )

    static func identity(at bundleURL: URL) throws -> AppCodeSignatureIdentity {
        try signedApplication(at: bundleURL).identity
    }

    static func validateReplacement(candidate: URL, replacing installed: URL) throws {
        let installedApplication = try signedApplication(at: installed)
        var requirement: SecRequirement?
        try checkStatus(SecCodeCopyDesignatedRequirement(installedApplication.code, SecCSFlags(rawValue: 0), &requirement))
        guard let requirement else {
            try checkStatus(OSStatus(errSecCSInternalError))
            return
        }

        // The installed signature, not candidate-controlled metadata, defines its publisher.
        let candidateApplication = try signedApplication(at: candidate, requirement: requirement)
        guard candidateApplication.identity.bundleIdentifier == installedApplication.identity.bundleIdentifier else {
            throw AppSecurityValidationError.bundleIdentifierMismatch(
                expected: installedApplication.identity.bundleIdentifier,
                actual: candidateApplication.identity.bundleIdentifier
            )
        }
    }

    static func applicationGroups(at bundleURL: URL) -> Set<String> {
        guard let code = try? validatedCode(at: bundleURL),
              let information = try? signingInformation(for: code),
              let entitlements = information[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else {
            return []
        }
        return Set(groups.lazy.filter(isSafeIdentifier))
    }

    static func isSafeIdentifier(_ identifier: String) -> Bool {
        !identifier.isEmpty
            && identifier != "."
            && !identifier.contains("..")
            && !identifier.contains("/")
            && !identifier.contains("\\")
            && !identifier.contains(":")
            && !identifier.contains("\0")
    }

    private static func signedApplication(
        at bundleURL: URL,
        requirement: SecRequirement? = nil
    ) throws -> (code: SecStaticCode, identity: AppCodeSignatureIdentity) {
        guard bundleURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
            throw AppSecurityValidationError.notAnApplication
        }
        let code = try validatedCode(at: bundleURL, requirement: requirement)
        let information = try signingInformation(for: code)
        guard let plist = information[kSecCodeInfoPList as String] as? [String: Any],
              let bundleIdentifier = plist["CFBundleIdentifier"] as? String,
              !bundleIdentifier.isEmpty,
              let signingIdentifier = information[kSecCodeInfoIdentifier as String] as? String,
              !signingIdentifier.isEmpty else {
            throw AppSecurityValidationError.notAnApplication
        }
        return (
            code,
            AppCodeSignatureIdentity(
                signingIdentifier: signingIdentifier,
                teamIdentifier: information[kSecCodeInfoTeamIdentifier as String] as? String,
                bundleIdentifier: bundleIdentifier
            )
        )
    }

    private static func validatedCode(at url: URL, requirement: SecRequirement? = nil) throws -> SecStaticCode {
        var code: SecStaticCode?
        try checkStatus(SecStaticCodeCreateWithPath(url.resolvingSymlinksInPath() as CFURL, SecCSFlags(rawValue: 0), &code))
        guard let code else {
            throw AppSecurityValidationError.notAnApplication
        }
        try checkStatus(SecStaticCodeCheckValidity(code, validationFlags, requirement))
        return code
    }

    private static func signingInformation(for code: SecStaticCode) throws -> [String: Any] {
        var information: CFDictionary?
        try checkStatus(SecCodeCopySigningInformation(code, SecCSFlags(rawValue: UInt32(kSecCSSigningInformation)), &information))
        guard let information = information as? [String: Any] else {
            throw AppSecurityValidationError.notAnApplication
        }
        return information
    }

    private static func checkStatus(_ status: OSStatus) throws {
        guard status != errSecSuccess else { return }
        throw NSError(
            domain: NSOSStatusErrorDomain,
            code: Int(status),
            userInfo: [NSLocalizedDescriptionKey: SecCopyErrorMessageString(status, nil) as String?
                ?? "Code signature validation failed (OSStatus \(status))."]
        )
    }
}
#endif