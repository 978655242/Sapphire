import Foundation
import XCTest
@testable import Sapphire

final class AppSecurityValidatorTests: XCTestCase {
    func testUnsignedAndUnsealedApplicationsCannotProvideVerifiedIdentity() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = try application(in: root, name: "Installed")
        try sign(installed)

        for name in ["Unsigned", "Unsealed"] {
            let candidate = try application(in: root, name: name)
            if name == "Unsigned" {
                try codesign(["--remove-signature", candidate.appendingPathComponent("Contents/MacOS/Fixture").path])
            }
            XCTAssertThrowsError(try AppSecurityValidator.identity(at: candidate))
            XCTAssertThrowsError(try AppSecurityValidator.validateReplacement(candidate: candidate, replacing: installed))
            XCTAssertThrowsError(try AppSecurityValidator.validateReplacement(candidate: installed, replacing: candidate))
            XCTAssertTrue(AppSecurityValidator.applicationGroups(at: candidate).isEmpty)
        }
    }

    func testIdentityAndApplicationGroupsComeFromValidatedSignature() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let app = try application(in: root, name: "Signed")
        try sign(app, identifier: "com.example.actual-signing-identifier", entitlements: [
            "com.apple.security.application-groups": ["group.com.example.signed", "../unsafe", "group:unsafe"],
            "com.apple.developer.team-identifier": "FORGEDTEAM",
        ])

        let identity = try AppSecurityValidator.identity(at: app)
        XCTAssertEqual(identity.signingIdentifier, "com.example.actual-signing-identifier")
        XCTAssertEqual(identity.bundleIdentifier, "com.example.fixture")
        XCTAssertNil(identity.teamIdentifier, "Ad-hoc signing must not promote an entitlement into a developer identity")
        XCTAssertEqual(AppSecurityValidator.applicationGroups(at: app), ["group.com.example.signed"])
    }

    func testResourceExecutableAndInfoPlistTamperingInvalidateIdentityAndReplacement() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = try application(in: root, name: "Installed")
        try sign(installed, entitlements: ["com.apple.security.application-groups": ["group.com.example.signed"]])

        for relativePath in ["Contents/Resources/payload", "Contents/MacOS/Fixture", "Contents/Info.plist"] {
            let candidate = root.appendingPathComponent("Candidate-\(UUID().uuidString).app")
            try FileManager.default.copyItem(at: installed, to: candidate)
            let file = candidate.appendingPathComponent(relativePath)
            var bytes = try Data(contentsOf: file)
            if relativePath == "Contents/MacOS/Fixture" {
                // Change executable content without corrupting its Mach-O header.
                bytes[4096] ^= 1
            } else {
                bytes.append(contentsOf: "tampered".utf8)
            }
            try bytes.write(to: file)

            XCTAssertThrowsError(try AppSecurityValidator.identity(at: candidate), relativePath)
            XCTAssertThrowsError(try AppSecurityValidator.validateReplacement(candidate: candidate, replacing: installed), relativePath)
            XCTAssertTrue(AppSecurityValidator.applicationGroups(at: candidate).isEmpty, relativePath)
        }
    }

    func testReplacementRequiresInstalledDesignatedRequirementNotJustMatchingIdentifiers() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = try application(in: root, name: "Installed")
        try sign(installed)
        let identical = root.appendingPathComponent("Identical.app")
        try FileManager.default.copyItem(at: installed, to: identical)
        XCTAssertNoThrow(try AppSecurityValidator.validateReplacement(candidate: identical, replacing: installed))

        let independentlySealed = try application(in: root, name: "Independent", version: "2")
        try sign(independentlySealed)
        XCTAssertEqual(try AppSecurityValidator.identity(at: independentlySealed), try AppSecurityValidator.identity(at: installed))
        // An ad-hoc designated requirement pins the code hash, not a claimed publisher.
        XCTAssertThrowsError(try AppSecurityValidator.validateReplacement(candidate: independentlySealed, replacing: installed))

        let wrongBundle = try application(in: root, name: "WrongBundle", bundleIdentifier: "com.example.other")
        try sign(wrongBundle)
        XCTAssertThrowsError(try AppSecurityValidator.validateReplacement(candidate: wrongBundle, replacing: installed))
    }

    func testNestedApplicationTamperingInvalidatesOuterSignature() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outer = try application(in: root, name: "Outer")
        let helpers = outer.appendingPathComponent("Contents/Library/LoginItems", isDirectory: true)
        try FileManager.default.createDirectory(at: helpers, withIntermediateDirectories: true)
        let nested = try application(in: helpers, name: "Helper", bundleIdentifier: "com.example.helper")
        try sign(nested)
        try sign(outer)
        XCTAssertNoThrow(try AppSecurityValidator.identity(at: outer))
        try Data("tampered".utf8).write(to: nested.appendingPathComponent("Contents/Resources/payload"))
        XCTAssertThrowsError(try AppSecurityValidator.identity(at: outer))
    }

    func testIdentifierValidationRejectsNulAndBackslash() {
        XCTAssertFalse(AppSecurityValidator.isSafeIdentifier("com\0example"))
        XCTAssertFalse(AppSecurityValidator.isSafeIdentifier("com\\example"))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AppSecurityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func application(in root: URL, name: String, bundleIdentifier: String = "com.example.fixture", version: String = "1") throws -> URL {
        let app = root.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/usr/bin/true"), to: contents.appendingPathComponent("MacOS/Fixture"))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: contents.appendingPathComponent("MacOS/Fixture").path)
        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleIdentifier,
            "CFBundleExecutable": "Fixture",
            "CFBundlePackageType": "APPL",
            "CFBundleVersion": version,
            "com.apple.security.application-groups": ["group.com.example.untrusted-plist"],
        ]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data("original".utf8).write(to: contents.appendingPathComponent("Resources/payload"))
        return app
    }

    private func sign(_ app: URL, identifier: String = "com.example.signing", entitlements: [String: Any] = [:]) throws {
        let plist = app.deletingLastPathComponent().appendingPathComponent("Entitlements-\(UUID().uuidString).plist")
        defer { try? FileManager.default.removeItem(at: plist) }
        try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0).write(to: plist)
        try codesign(["--force", "--sign", "-", "--timestamp=none", "--identifier", identifier, "--entitlements", plist.path, app.path])
    }

    private func codesign(_ arguments: [String]) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errors
        try process.run()
        let output = errors.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw NSError(domain: "AppSecurityTestFixture", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: String(decoding: output, as: UTF8.self),
            ])
        }
    }
}
