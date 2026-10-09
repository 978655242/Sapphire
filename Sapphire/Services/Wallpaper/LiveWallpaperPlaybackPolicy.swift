//
//  LiveWallpaperPlaybackPolicy.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-09-15.
//

import AppKit

@MainActor
final class LiveWallpaperPlaybackPolicy {
    enum Reason: String, CaseIterable {
        case displaysAsleep
        case systemSleeping
        case sessionInactive
        case thermalPressure
    }

    var onChange: ((Set<Reason>) -> Void)?

    private(set) var reasons: Set<Reason> = []

    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var isRunning = false

    var isSuspended: Bool { !reasons.isEmpty }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.screensDidSleepNotification) { $0.set(.displaysAsleep, true) }
        observe(workspace, NSWorkspace.screensDidWakeNotification) { $0.set(.displaysAsleep, false) }
        observe(workspace, NSWorkspace.willSleepNotification) { $0.set(.systemSleeping, true) }
        observe(workspace, NSWorkspace.didWakeNotification) { $0.set(.systemSleeping, false) }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification) { $0.set(.sessionInactive, true) }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification) { $0.set(.sessionInactive, false) }
        observe(.default, ProcessInfo.thermalStateDidChangeNotification) { $0.refreshThermalReason() }

        refreshThermalReason()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        for (center, token) in observers {
            center.removeObserver(token)
        }
        observers.removeAll()
        commit([])
    }

    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        handler: @escaping @MainActor (LiveWallpaperPlaybackPolicy) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        observers.append((center, token))
    }

    private func set(_ reason: Reason, _ active: Bool) {
        var next = reasons
        if active { next.insert(reason) } else { next.remove(reason) }
        commit(next)
    }

    private func refreshThermalReason() {
        guard isRunning else { return }
        var next = reasons
        let info = ProcessInfo.processInfo
        toggle(&next, .thermalPressure, info.thermalState == .serious || info.thermalState == .critical)
        commit(next)
    }

    private func toggle(_ set: inout Set<Reason>, _ reason: Reason, _ active: Bool) {
        if active { set.insert(reason) } else { set.remove(reason) }
    }

    private func commit(_ next: Set<Reason>) {
        guard next != reasons else { return }
        reasons = next
        onChange?(next)
    }

}