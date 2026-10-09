//
//  ScheduleManager.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-07-19.
//

import Foundation
import Combine
import AppKit

enum TaskAction: String, Codable, CaseIterable, Identifiable {
    case setFanAuto, setFanConstant, setFanSensorBased

    var id: String { self.rawValue }

    var displayName: String {
        switch self {
        case .setFanAuto: "Set Fans to Automatic".local
        case .setFanConstant: "Set Fans to Constant RPM".local
        case .setFanSensorBased: "Set Fans to Sensor-based".local
        }
    }
}

struct ScheduledTask: Codable, Equatable, Identifiable {
    var id = UUID()
    var action: TaskAction = .setFanAuto
    var repeatInterval: RepeatInterval = .never
    var startTime: Date = Date()
    var fanSpeed: Int = 2500
    var sensorKey: String = ""
    var minTemp: Int = 40
    var maxTemp: Int = 75
    var isActive: Bool = true
}

enum RepeatInterval: String, Codable, CaseIterable, Identifiable {
    case never, daily, weekdays, weekly, biweekly, monthly
    var id: String { self.rawValue }
    var displayName: String { rawValue.capitalized.local }
}
struct TaskHistoryEvent: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let taskDescription: String
}

@MainActor
class ScheduleManager: ObservableObject {
    static let shared = ScheduleManager()

    // MARK: - Dependencies
    private let settings = SettingsModel.shared
    private let fanManager = FanManager.shared

    // MARK: - Properties
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var notificationObservers: [(NotificationCenter, NSObjectProtocol)] = []

    private struct Configuration: Equatable {
        let tasks: [ScheduledTask]

        init(_ settings: Settings) {
            tasks = settings.scheduledTasks
        }
    }

    @Published var taskHistory: [TaskHistoryEvent] = []

    private init() {
        settings.changes(of: Configuration.init)
            .sink { [weak self] _ in self?.checkScheduledTasks() }
            .store(in: &cancellables)

        observe(
            [.NSCalendarDayChanged, .NSSystemClockDidChange, .NSSystemTimeZoneDidChange,
             NSApplication.didBecomeActiveNotification],
            in: .default
        )
        observe([NSWorkspace.didWakeNotification], in: NSWorkspace.shared.notificationCenter)
        checkScheduledTasks()
    }

    deinit {
        timer?.invalidate()
        for (center, observer) in notificationObservers {
            center.removeObserver(observer)
        }
    }

    private func observe(_ names: [Notification.Name], in center: NotificationCenter) {
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.checkScheduledTasks() }
            }
            notificationObservers.append((center, observer))
        }
    }

    private func checkScheduledTasks() {
        let now = Date()
        let calendar = Calendar.current

        for task in settings.settings.scheduledTasks where task.isActive {
            let scheduledTime = calendar.dateComponents([.hour, .minute], from: task.startTime)
            let nowTime = calendar.dateComponents([.hour, .minute], from: now)

            guard scheduledTime.hour == nowTime.hour && scheduledTime.minute == nowTime.minute else {
                continue
            }

            var shouldRun = false
            switch task.repeatInterval {
            case .never:
                let lastRun = taskHistory.first(where: { $0.taskDescription.contains(task.action.displayName) })?.timestamp
                if lastRun == nil || !calendar.isDateInToday(lastRun!) {
                    shouldRun = true
                }
            case .daily:
                shouldRun = true
            case .weekdays:
                let weekday = calendar.component(.weekday, from: now)
                shouldRun = (weekday >= 2 && weekday <= 6)
            case .weekly:
                shouldRun = calendar.component(.weekday, from: now) == calendar.component(.weekday, from: task.startTime)
            case .biweekly:
                 let weeksSinceStart = calendar.dateComponents([.weekOfYear], from: task.startTime, to: now).weekOfYear ?? 0
                 if weeksSinceStart % 2 == 0 {
                     shouldRun = calendar.component(.weekday, from: now) == calendar.component(.weekday, from: task.startTime)
                 }
            case .monthly:
                shouldRun = calendar.component(.day, from: now) == calendar.component(.day, from: task.startTime)
            }

            if shouldRun {
                executeTask(task)
            }
        }

        scheduleNextCheck(after: now)
    }

    private func scheduleNextCheck(after now: Date) {
        timer?.invalidate()
        timer = nil

        let candidates = settings.settings.scheduledTasks
            .filter(\.isActive)
            .compactMap { nextFireDate(for: $0, after: now) }

        guard let nextDate = candidates.min() else { return }
        let delay = max(0.05, nextDate.timeIntervalSinceNow)
        let nextTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.timer = nil
                self?.checkScheduledTasks()
            }
        }
        nextTimer.tolerance = min(1, delay * 0.05)
        timer = nextTimer
    }

    private func nextFireDate(for task: ScheduledTask, after now: Date) -> Date? {
        let calendar = Calendar.current
        let time = calendar.dateComponents([.hour, .minute], from: task.startTime)
        guard let hour = time.hour, let minute = time.minute,
              let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return nil
        }

        for dayOffset in 0..<800 {
            guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  candidate > now else { continue }

            let matches = switch task.repeatInterval {
            case .never, .daily:
                true
            case .weekdays:
                (2...6).contains(calendar.component(.weekday, from: candidate))
            case .weekly:
                calendar.component(.weekday, from: candidate)
                    == calendar.component(.weekday, from: task.startTime)
            case .biweekly:
                (calendar.dateComponents([.weekOfYear], from: task.startTime, to: candidate).weekOfYear ?? 0) % 2 == 0
                    && calendar.component(.weekday, from: candidate)
                        == calendar.component(.weekday, from: task.startTime)
            case .monthly:
                calendar.component(.day, from: candidate)
                    == calendar.component(.day, from: task.startTime)
            }
            if matches { return candidate }
        }
        return nil
    }

    private func executeTask(_ task: ScheduledTask) {
        logTaskExecution(task)

        switch task.action {
        case .setFanAuto:
            print("[ScheduleManager] Executing task: Set Fans to Automatic.")
            for fan in fanManager.fans {
                fanManager.setFanMode(for: fan.id, to: .auto)
            }
        case .setFanConstant:
            print("[ScheduleManager] Executing task: Set Fans to \(task.fanSpeed) RPM.")
            for fan in fanManager.fans {
                fanManager.setFanMode(for: fan.id, to: .constant(rpm: task.fanSpeed))
            }
        case .setFanSensorBased:
            print("[ScheduleManager] Executing task: Set Fans to Sensor-based (\(task.sensorKey), \(task.minTemp)°C-\(task.maxTemp)°C).")
            for fan in fanManager.fans {
                fanManager.setFanMode(for: fan.id, to: .sensor(sensorKey: task.sensorKey, minTemp: task.minTemp, maxTemp: task.maxTemp))
            }
        }
    }

    private func logTaskExecution(_ task: ScheduledTask) {
        let event = TaskHistoryEvent(timestamp: Date(), taskDescription: String(localized: "Executed: \(task.action.displayName)"))
        DispatchQueue.main.async {
            self.taskHistory.insert(event, at: 0)
        }
    }
}