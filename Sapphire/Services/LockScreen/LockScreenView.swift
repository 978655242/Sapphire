//
//  LockScreenView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-09-11.
//

import SwiftUI
import AppKit

// MARK: - Lock Screen Navigation
enum LockScreenMusicView: Hashable {
    case player
    case queueAndPlaylists
    case playlistDetail(SpotifyPlaylist)
    case devices
    case lyrics
    case loginPrompt
}

class LockScreenNavigationManager: ObservableObject {
    @Published var viewStack: [LockScreenMusicView] = [.player]

    var currentView: LockScreenMusicView {
        viewStack.last ?? .player
    }

    func navigateTo(_ view: LockScreenMusicView) {
        viewStack.append(view)
    }

    func goBack() {
        if viewStack.count > 1 {
            _ = viewStack.popLast()
        }
    }
}

private struct LockScreenBackButton: View {
    @EnvironmentObject var navigationManager: LockScreenNavigationManager

    var body: some View {
        Button(action: {
            navigationManager.goBack()
        }) {
            Image(systemName: "chevron.backward")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.15).clipShape(Circle()))
        }
        .buttonStyle(.plain)
        .padding()
    }
}

// MARK: - Environment Keys
private struct LockScreenWidgetHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

private extension EnvironmentValues {
    var lockScreenWidgetHeight: CGFloat? {
        get { self[LockScreenWidgetHeightKey.self] }
        set { self[LockScreenWidgetHeightKey.self] = newValue }
    }
}

struct LockScreenMiniWidgetHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    var lockScreenMiniWidgetHeight: CGFloat? {
        get { self[LockScreenMiniWidgetHeightKey.self] }
        set { self[LockScreenMiniWidgetHeightKey.self] = newValue }
    }
}

// MARK: - Main View Container
struct LockScreenMainWidgetContainerView: View {
    @EnvironmentObject var settings: SettingsModel
    @EnvironmentObject private var musicManager: MusicManager
    @StateObject private var navigationManager = LockScreenNavigationManager()
    @State private var maxMainWidgetHeight: CGFloat = 0
    @State private var dummyStack: [NotchWidgetMode] = []
    private var isSpotifyAuthenticated: Bool {
        musicManager.isPrivateAPIAuthenticated || musicManager.isOfficialAPIAuthenticated
    }
    private var requiresSpotifyLogin: Bool {
        musicManager.musicContentSource.requiresSpotifyLogin(authenticated: isSpotifyAuthenticated)
    }

    var body: some View {
        HStack(alignment: .top, spacing: LockScreenConfiguration.widgetSpacing) {
            ForEach(settings.settings.lockScreenMainWidgets, id: \.self) { widgetType in
                widgetView(for: widgetType)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: navigationManager.currentView)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: maxMainWidgetHeight)
        .fixedSize(horizontal: true, vertical: false)
        .onPreferenceChange(SizePreferenceKey.self) { sizes in
            let maxHeight = sizes.map(\.height).max() ?? 0
            if maxMainWidgetHeight != maxHeight {
                maxMainWidgetHeight = maxHeight
            }
        }
        .environment(\.lockScreenWidgetHeight, maxMainWidgetHeight > 0 ? maxMainWidgetHeight : nil)
        .environmentObject(navigationManager)
        .id("main-widget-\(navigationManager.currentView)")
        .onAppear { normalizeMusicNavigation() }
        .onChange(of: musicManager.musicContentSource) { _, _ in
            switch navigationManager.currentView {
            case .queueAndPlaylists, .playlistDetail, .loginPrompt:
                navigationManager.viewStack = [.player]
            case .devices, .lyrics:
                navigationManager.viewStack = [.player, navigationManager.currentView]
            case .player:
                navigationManager.viewStack = [.player]
            }
        }
        .onChange(of: isSpotifyAuthenticated) { _, _ in normalizeMusicNavigation() }
    }

    @ViewBuilder
    private func widgetView(for widgetType: LockScreenMainWidgetType) -> some View {
        let fadeTransition = AnyTransition.opacity.animation(.easeInOut(duration: 0.2))

        switch widgetType {
        case .music:
            LockScreenConditionalMusicView(
                showWhenPaused: settings.settings.lockScreenShowMusicWhenPaused
            ) {
                musicNavigationHostView
            }
            .transition(fadeTransition)
        case .weather:
            LockScreenWeatherView()
                .transition(fadeTransition)
        case .calendar:
            LockScreenCalendarView()
                .transition(fadeTransition)
        case .focus:
            LockScreenFocusMainView()
                .transition(fadeTransition)
        case .timer:
            LockScreenTimerMainView()
                .transition(fadeTransition)
        case .notes:
            LockScreenNotesMainView()
                .transition(fadeTransition)
        case .clipboard:
            LockScreenClipboardMainView()
                .transition(fadeTransition)
        }
    }

    @ViewBuilder
    private var musicNavigationHostView: some View {
        ZStack {
            switch navigationManager.currentView {
            case .player:
                LockScreenView()
            case .queueAndPlaylists:
                if musicManager.musicContentSource.supportsLibrary {
                    LockScreenPaddedBackground {
                        ZStack(alignment: .topLeading) {
                            if requiresSpotifyLogin {
                                LoginPromptView(navigationStack: $dummyStack)
                            } else {
                                QueueAndPlaylistsView(navigationStack: $dummyStack, isLockScreenMode: true)
                            }
                            LockScreenBackButton()
                                .padding(.top, 52)
                                .zIndex(10)
                        }
                    }
                } else {
                    LockScreenView()
                }
            case .playlistDetail(let playlist):
                if isPlaylistAvailable(playlist) {
                    LockScreenPaddedBackground {
                        ZStack(alignment: .topLeading) {
                            PlaylistView(playlist: playlist, isLockScreenMode: true)
                            LockScreenBackButton()
                                .padding(.top, 52)
                                .zIndex(10)
                        }
                    }
                } else {
                    LockScreenView()
                }
            case .devices:
                LockScreenPaddedBackground {
                    ZStack(alignment: .topLeading) {
                        DevicesView(
                            navigationStack: $dummyStack,
                            audioHubSection: .constant(.system),
                            isLockScreenMode: true,
                            preferSystemTab: musicManager.musicContentSource != .spotify
                        )
                        LockScreenBackButton()
                            .padding(.top, 52)
                            .zIndex(10)
                    }
                }
            case .lyrics:
                 LockScreenPaddedBackground {
                    ZStack(alignment: .topLeading) {
                        LyricsView()
                        LockScreenBackButton()
                            .padding(.top, 52)
                            .zIndex(10)
                    }
                }
            case .loginPrompt:
                if requiresSpotifyLogin {
                    LockScreenPaddedBackground {
                        ZStack(alignment: .topLeading) {
                            LoginPromptView(navigationStack: $dummyStack)
                            LockScreenBackButton()
                                .padding(.top, 52)
                                .zIndex(10)
                        }
                    }
                } else {
                    LockScreenView()
                }
            }
        }
    }

    private func isPlaylistAvailable(_ playlist: SpotifyPlaylist) -> Bool {
        switch musicManager.musicContentSource {
        case .appleMusic:
            return !playlist.uri.hasPrefix("spotify:")
        case .spotify:
            return isSpotifyAuthenticated && playlist.uri.hasPrefix("spotify:")
        case .system:
            return false
        }
    }

    private func normalizeMusicNavigation() {
        switch navigationManager.currentView {
        case .queueAndPlaylists:
            if !musicManager.musicContentSource.supportsLibrary {
                navigationManager.viewStack = [.player]
            }
        case .playlistDetail(let playlist):
            if !isPlaylistAvailable(playlist) { navigationManager.viewStack = [.player] }
        case .loginPrompt:
            if !requiresSpotifyLogin { navigationManager.viewStack = [.player] }
        default:
            break
        }
    }

}

private struct LockScreenConditionalMusicView<Content: View>: View {
    @EnvironmentObject private var musicManager: MusicManager

    let showWhenPaused: Bool
    let content: Content

    init(showWhenPaused: Bool, @ViewBuilder content: () -> Content) {
        self.showWhenPaused = showWhenPaused
        self.content = content()
    }

    var body: some View {
        let hasTrack = !(musicManager.title?.isEmpty ?? true)
        if musicManager.isPlaying || (showWhenPaused && hasTrack) {
            content
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
        }
    }
}

// MARK: - Reusable Background
struct LockScreenPaddedBackground<Content: View>: View {
    @Environment(\.lockScreenWidgetHeight) private var _lockScreenWidgetHeight: CGFloat?
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(LockScreenConfiguration.backgroundPadding)
            .measureSize()
            .frame(minHeight: _lockScreenWidgetHeight, alignment: .top)
            .background(backgroundMaterial)
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
        LockScreenWidgetSurface(
            shape: RoundedRectangle(cornerRadius: LockScreenConfiguration.cornerRadius, style: .continuous),
            cornerRadius: LockScreenConfiguration.cornerRadius
        )
    }
}

// MARK: - Specific Widget Views
struct LockScreenView: View {
    @State private var dummyNavigationStack: [NotchWidgetMode] = [.musicPlayer]

    var body: some View {
        LockScreenPaddedBackground {
            MusicPlayerView(navigationStack: $dummyNavigationStack, isLockScreenMode: true)
        }
    }
}

struct LockScreenWeatherView: View {
    @Environment(\.lockScreenWidgetHeight) private var _lockScreenWidgetHeight: CGFloat?

    var body: some View {
        WeatherPlayerView()
            .padding(LockScreenConfiguration.backgroundPadding)
            .measureSize()
            .frame(minHeight: _lockScreenWidgetHeight, alignment: .top)
            .background(
                LockScreenWidgetSurface(
                    shape: RoundedRectangle(cornerRadius: LockScreenConfiguration.cornerRadius, style: .continuous),
                    cornerRadius: LockScreenConfiguration.cornerRadius
                )
            )
    }
}

struct LockScreenCalendarView: View {
    @Environment(\.lockScreenWidgetHeight) private var _lockScreenWidgetHeight: CGFloat?

    var body: some View {
        CalendarDetailView()
            .padding(LockScreenConfiguration.backgroundPadding)
            .measureSize()
            .frame(minHeight: _lockScreenWidgetHeight, alignment: .top)
            .background(
                LockScreenWidgetSurface(
                    shape: RoundedRectangle(cornerRadius: LockScreenConfiguration.cornerRadius, style: .continuous),
                    cornerRadius: LockScreenConfiguration.cornerRadius
                )
            )
    }
}