//
//  CrossfadeOrchestrator.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-21

import AudioToolbox
import os

enum CrossfadeError: LocalizedError {
    case tapCreationFailed(OSStatus)
    case aggregateCreationFailed(OSStatus)
    case deviceNotReady
    case secondaryTapFailed
    case noTapDescription

    var errorDescription: String? {
        switch self {
        case .tapCreationFailed(let status):
            return String(format: NSLocalizedString("Failed to create process tap: %d", comment: ""), status)
        case .aggregateCreationFailed(let status):
            return String(format: NSLocalizedString("Failed to create aggregate device: %d", comment: ""), status)
        case .deviceNotReady:
            return NSLocalizedString("Device not ready within timeout", comment: "")
        case .secondaryTapFailed:
            return NSLocalizedString("Secondary tap invalid after timeout", comment: "")
        case .noTapDescription:
            return NSLocalizedString("No tap description available", comment: "")
        }
    }
}

enum CrossfadeConfig {
    static let defaultDuration: TimeInterval = 0.050

    static var duration: TimeInterval {
        let custom = UserDefaults.standard.double(forKey: "SapphireCrossfadeDuration")
        return custom > 0 ? custom : defaultDuration
    }

    static func totalSamples(at sampleRate: Double) -> Int64 {
        max(1, Int64(sampleRate * duration))
    }
}