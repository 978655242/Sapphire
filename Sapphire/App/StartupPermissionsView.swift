import SwiftUI

struct StartupPermissionsView: View {
    @ObservedObject private var manager = PermissionsManager.shared
    @State private var handled = Set<PermissionType>()
    @State private var requested = Set<PermissionType>()
    let onComplete: () -> Void

    private var current: PermissionItem? {
        let type = PermissionsManager.nextLaunchPermission(
            in: manager.allPermissions.map { ($0.type, manager.status(for: $0.type)) },
            excluding: handled
        )
        return manager.allPermissions.first { $0.type == type }
    }

    private var isAwaitingDecision: Bool {
        if current?.type == .location && manager.isRequestingLocation { return true }
        guard let type = current?.type,
              requested.contains(type), manager.status(for: type) == .notRequested else { return false }
        // These requests finish via system callbacks; settings-only permissions stay skippable.
        return type != .accessibility && type != .fullDiskAccess && type != .screenRecording
    }

    var body: some View {
        VStack(spacing: 20) {
            if let permission = current {
                Image(systemName: permission.iconName)
                    .font(.system(size: 36))
                    .foregroundStyle(permission.iconColor)
                    .accessibilityHidden(true)
                Text(permission.title).font(.title2.bold())
                Text(permission.description)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Skip".local) { handled.insert(permission.type) }
                        .disabled(isAwaitingDecision)
                    Spacer()
                    Button("Check Again".local) {
                        Task { await manager.refreshLaunchPermissions() }
                    }
                    Button(actionTitle(for: permission.type)) {
                        if manager.status(for: permission.type) == .denied || requested.contains(permission.type) {
                            manager.openPermissionSettings(permission.type)
                        } else {
                            requested.insert(permission.type)
                            manager.requestPermission(permission.type)
                            manager.checkAllPermissions()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isAwaitingDecision)
                }
                Button("Cancel".local, action: onComplete)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(28)
        .frame(width: 520, height: 300)
        .onChange(of: current?.type) { _, type in
            if type == nil { onComplete() }
        }
    }

    private func actionTitle(for type: PermissionType) -> String {
        manager.status(for: type) == .denied || requested.contains(type)
            ? "Open System Settings".local : "Request".local
    }
}
