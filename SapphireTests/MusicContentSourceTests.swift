import XCTest
@testable import Sapphire

final class MusicContentSourceTests: XCTestCase {
    func testNetEaseNeverRequiresSpotifyLoginOrExposesItsLibrary() {
        let source = MusicContentSource.resolve(
            bundleIdentifier: "com.netease.163music",
            spotifySelected: false,
            phoneSelected: false
        )

        XCTAssertFalse(source.supportsLibrary)
        XCTAssertFalse(source.requiresSpotifyLogin(authenticated: false))
        XCTAssertFalse(source.requiresSpotifyLogin(authenticated: true))
    }

    func testSpotifyLibraryRequiresLoginUntilAuthenticated() {
        let source = MusicContentSource.resolve(
            bundleIdentifier: "com.spotify.client",
            spotifySelected: true,
            phoneSelected: false
        )

        XCTAssertTrue(source.supportsLibrary)
        XCTAssertTrue(source.requiresSpotifyLogin(authenticated: false))
        XCTAssertFalse(source.requiresSpotifyLogin(authenticated: true))
    }

    func testAppleMusicLibraryDoesNotRequireSpotifyAuthentication() {
        let source = MusicContentSource.resolve(
            bundleIdentifier: "com.apple.Music",
            spotifySelected: false,
            phoneSelected: false
        )

        XCTAssertTrue(source.supportsLibrary)
        XCTAssertFalse(source.requiresSpotifyLogin(authenticated: false))
    }

    func testExplicitSpotifySelectionWinsOverStaleAppleMusicMetadata() {
        let source = MusicContentSource.resolve(
            bundleIdentifier: "com.apple.Music",
            spotifySelected: true,
            phoneSelected: false
        )

        XCTAssertTrue(source.requiresSpotifyLogin(authenticated: false))
    }

    func testPhoneMediaCannotUseTheMacSpotifyOrAppleMusicLibrary() {
        let source = MusicContentSource.resolve(
            bundleIdentifier: "com.apple.Music",
            spotifySelected: true,
            phoneSelected: true
        )
        XCTAssertFalse(source.supportsLibrary)
        XCTAssertFalse(source.requiresSpotifyLogin(authenticated: false))
    }

    func testMissingMediaIdentityDoesNotRequestSpotifyLogin() {
        let source = MusicContentSource.resolve(
            bundleIdentifier: nil,
            spotifySelected: false,
            phoneSelected: false
        )

        XCTAssertFalse(source.supportsLibrary)
        XCTAssertFalse(source.requiresSpotifyLogin(authenticated: false))
    }
}
