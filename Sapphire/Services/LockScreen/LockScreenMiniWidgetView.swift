//
//  LockScreenMiniWidgetView.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-05.
//

import SwiftUI

struct LockScreenWidgetBackground<Content: View>: View {
    @Environment(\.lockScreenMiniWidgetHeight) private var equalizedHeight: CGFloat?

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(LockScreenConfiguration.backgroundPadding)
            .measureSize()
            .frame(minHeight: equalizedHeight, alignment: .top)
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

struct LockScreenMiniWidgetView: View {
    @EnvironmentObject var settings: SettingsModel


    @StateObject private var calendarViewModel = InteractiveCalendarViewModel()
    @State private var dummyNavigationStack: [NotchWidgetMode] = []

    @State private var maxMiniWidgetHeight: CGFloat = 0

    private var animationToken: String {
        let widgets = settings.settings.lockScreenMiniWidgets.map(\.rawValue).joined(separator: ",")
        return "\(widgets)-\(Int(maxMiniWidgetHeight))"
    }

    var body: some View {
        let fadeTransition = AnyTransition.opacity.combined(with: .scale(scale: 0.98))

        HStack(alignment: .top, spacing: LockScreenConfiguration.widgetSpacing) {
            ForEach(settings.settings.lockScreenMiniWidgets, id: \.self) { widgetType in
                switch widgetType {
                case .weather:
                    LockScreenWidgetBackground {
                        WeatherWidgetView()
                            .environment(\.navigationStack, $dummyNavigationStack)
                    }
                    .transition(fadeTransition)

                case .calendar:
                    LockScreenWidgetBackground {
                        CalendarWidgetView(viewModel: calendarViewModel)
                            .environment(\.navigationStack, $dummyNavigationStack)
                    }
                    .transition(fadeTransition)

                case .music:
                    LockScreenMusicMiniSlot()
                        .environment(\.navigationStack, $dummyNavigationStack)
                        .transition(fadeTransition)

                case .focus:
                    LockScreenWidgetBackground {
                        LockScreenFocusMiniWidget()
                    }
                    .transition(fadeTransition)

                case .caffeine:
                    LockScreenWidgetBackground {
                        LockScreenCaffeineMiniWidget()
                    }
                    .transition(fadeTransition)

                case .timer:
                    LockScreenTimerMiniSlot()
                        .transition(fadeTransition)

                case .bluetooth:
                    LockScreenWidgetBackground {
                        LockScreenBluetoothMiniWidget()
                    }
                    .transition(fadeTransition)

                case .clipboard:
                    LockScreenWidgetBackground {
                        ClipboardWidgetView()
                    }
                    .transition(fadeTransition)

                case .notes:
                    LockScreenWidgetBackground {
                        NotesWidgetView()
                    }
                    .transition(fadeTransition)

                case .system:
                    LockScreenWidgetBackground {
                        LockScreenSystemMiniWidget()
                    }
                    .transition(fadeTransition)

                case .none:
                    EmptyView()
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: animationToken)
        .fixedSize(horizontal: true, vertical: false)
        .onPreferenceChange(SizePreferenceKey.self) { sizes in
            let maxHeight = sizes.map(\.height).max() ?? 0
            if maxMiniWidgetHeight != maxHeight {
                maxMiniWidgetHeight = maxHeight
            }
        }
        .environment(\.lockScreenMiniWidgetHeight, maxMiniWidgetHeight > 0 ? maxMiniWidgetHeight : nil)
    }

}

private struct LockScreenMusicMiniSlot: View {
    @EnvironmentObject private var musicManager: MusicManager

    var body: some View {
        Group {
            if musicManager.isPlaying {
                LockScreenWidgetBackground {
                    MusicWidgetView(onExpand: {
                        LockScreenMusicPaneController.shared.open()
                    })
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: musicManager.isPlaying)
    }
}

private struct LockScreenTimerMiniSlot: View {
    @EnvironmentObject private var settings: SettingsModel
    @EnvironmentObject private var timerManager: TimerManager

    var body: some View {
        Group {
            if timerManager.isRunning || !settings.settings.lockScreenHideInactiveInfoWidgets {
                LockScreenWidgetBackground {
                    LockScreenTimerMiniWidget()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: timerManager.isRunning)
    }
}
