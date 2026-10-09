//
//  PremiumFeatureViews.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15

#if !SAPPHIRE_FULL_BUILD
import SwiftUI


private struct PremiumUnavailableView: View {
    let title: String

    var body: some View {
        Text("\(title) is not included in this build.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KeyboardShortcutsSettingsView: View { var body: some View { PremiumUnavailableView(title: "Keyboard Shortcuts".local) } }
struct ContinuitySettingsView: View { var body: some View { PremiumUnavailableView(title: "Continuity".local) } }
struct EmojiSettingsView: View { var body: some View { PremiumUnavailableView(title: "Emoji".local) } }
struct MouseSettingsView: View { var body: some View { PremiumUnavailableView(title: "Mouse".local) } }
struct DockLayoutsSettingsView: View { var body: some View { PremiumUnavailableView(title: "Dock Layouts".local) } }
struct MediaOptimizerSettingsView: View { var body: some View { PremiumUnavailableView(title: "Media Optimizer".local) } }

struct StorageWorkspaceView: View {
    @ObservedObject var model: StorageViewModel
    var body: some View { PremiumUnavailableView(title: "Storage Workspace".local) }
}

struct EightDAudioView: View {
    let bundleID: String
    let appName: String
    var body: some View { PremiumUnavailableView(title: "8D Audio".local) }
}

struct SurroundAudioView: View {
    let bundleID: String
    let appName: String
    var body: some View { PremiumUnavailableView(title: "Surround Audio".local) }
}

struct StorageDetailView: View {
    var body: some View { PremiumUnavailableView(title: "Storage".local) }
}

struct StorageWidgetView: View {
    var body: some View { EmptyView() }
}

struct ClipboardItemThumbnailView: View {
    let item: ClipboardItem
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 7
    var fallbackSystemImage = "photo"
    var fallbackTint: Color = .purple
    var strokeColor: Color?

    var body: some View {
        Image(systemName: fallbackSystemImage)
            .foregroundStyle(fallbackTint)
            .frame(width: size, height: size)
    }
}
#endif