//
//  BluetoothManager.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-07-07.
//

import Foundation
import Combine
import IOBluetooth
import AppKit

struct BluetoothDeviceState: Hashable {
    enum EventType: Hashable {
        case connected, disconnected
    }
    let eventUUID = UUID()
    let id: String, name: String, iconName: String, eventType: EventType
    let isContinuityDevice: Bool
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.eventUUID == rhs.eventUUID }
    func hash(into hasher: inout Hasher) { hasher.combine(eventUUID) }
}

@MainActor
class BluetoothManager: NSObject, ObservableObject {
    @Published var lastEvent: BluetoothDeviceState?

    var isBluetoothPoweredOn: Bool {
        IOBluetoothHostController.default()?.powerState == kBluetoothHCIPowerStateON
    }

    private var connectionNotification: IOBluetoothUserNotification?
    private var disconnectionNotifications: [String: IOBluetoothUserNotification] = [:]
    private var recentlyConnectedDebounceSet: Set<String> = []

    private var cancellables = Set<AnyCancellable>()
    private var isProximityScanActive = false

    override init() {
        super.init()

        self.connectionNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnected(_:device:))
        )

        isProximityScanActive = AuthenticationManager.shared.isScanning
        AuthenticationManager.shared.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isScanning in
                self?.isProximityScanActive = isScanning
            }
            .store(in: &cancellables)

        checkForInitiallyConnectedDevices()
    }

    deinit {
        connectionNotification?.unregister()
        disconnectionNotifications.values.forEach { $0.unregister() }
    }

    @objc private func deviceConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        Task { @MainActor [weak self] in
            self?.handleDeviceConnected(device: device)
        }
    }

    @MainActor
    private func handleDeviceConnected(device: IOBluetoothDevice) {
        guard !isProximityScanActive else {
            registerForDisconnect(device: device)
            return
        }

        guard let address = device.addressString, let name = device.name else { return }

        if recentlyConnectedDebounceSet.contains(address) { return }
        recentlyConnectedDebounceSet.insert(address)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.recentlyConnectedDebounceSet.remove(address)
        }

        if SettingsModel.shared.settings.bluetoothNotifySound {
            if let soundURL = Bundle.main.url(forResource: "head_gestures_double_nod", withExtension: "caf") {
                NSSound(contentsOf: soundURL, byReference: true)?.play()
            } else {
                NSSound(named: "Tink")?.play()
            }
        }

        self.lastEvent = BluetoothDeviceState(
            id: address,
            name: name,
            iconName: IconMapper.icon(for: device),
            eventType: .connected,
            isContinuityDevice: isContinuityDevice(name: name)
        )

        registerForDisconnect(device: device)
    }

    private func registerForDisconnect(device: IOBluetoothDevice) {
        guard let address = device.addressString else { return }
        if self.disconnectionNotifications[address] == nil {
            self.disconnectionNotifications[address] = device.register(
                forDisconnectNotification: self,
                selector: #selector(self.deviceDisconnected(_:device:))
            )
        }
    }

    @objc private func deviceDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        Task { @MainActor [weak self] in
            self?.handleDeviceDisconnected(device: device)
        }
    }

    @MainActor
    private func handleDeviceDisconnected(device: IOBluetoothDevice) {
        guard !isProximityScanActive else {
            if let address = device.addressString, let notificationToRemove = disconnectionNotifications.removeValue(forKey: address) {
                notificationToRemove.unregister()
            }
            return
        }

        guard let address = device.addressString, let name = device.name else { return }

        if SettingsModel.shared.settings.bluetoothNotifySound {
            if let soundURL = Bundle.main.url(forResource: "jbl_cancel", withExtension: "caf") {
                NSSound(contentsOf: soundURL, byReference: true)?.play()
            } else {
                NSSound(named: "Tink")?.play()
            }
        }

        let iconName = IconMapper.icon(for: device)

        let deviceState = BluetoothDeviceState(
            id: address, name: name, iconName: iconName,
            eventType: .disconnected, isContinuityDevice: isContinuityDevice(name: name)
        )
        self.lastEvent = deviceState

        if let notificationToRemove = disconnectionNotifications.removeValue(forKey: address) {
            notificationToRemove.unregister()
        }
    }

    private func checkForInitiallyConnectedDevices() {
        guard let pairedDevices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        for device in pairedDevices where device.isConnected() {
            handleDeviceConnected(device: device)
        }
    }

    private func isContinuityDevice(name: String) -> Bool {
        let lowercasedName = name.lowercased()
        let keywords = ["macbook", "imac", "mac mini", "mac studio", "mac pro", "iphone", "ipad", "apple watch", "vision pro"]
        return keywords.contains { lowercasedName.contains($0) }
    }
}