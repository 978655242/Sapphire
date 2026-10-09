//
//  Helper.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-02
//

import Foundation
import os.log
import CoreAudio
import IOKit
import Security
import Darwin

private enum HelperSapphireVersionOrdering {
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = ParsedVersion(lhs)
        let right = ParsedVersion(rhs)

        let major = compareInteger(left.core.first ?? "0", right.core.first ?? "0")
        if major != .orderedSame { return major }

        let minor = compareFraction(
            left.core.count > 1 ? left.core[1] : "0",
            right.core.count > 1 ? right.core[1] : "0"
        )
        if minor != .orderedSame { return minor }

        let coreCount = max(left.core.count, right.core.count)
        if coreCount > 2 {
            for index in 2..<coreCount {
                let component = compareInteger(
                    index < left.core.count ? left.core[index] : "0",
                    index < right.core.count ? right.core[index] : "0"
                )
                if component != .orderedSame { return component }
            }
        }

        return comparePrerelease(left.prerelease, right.prerelease)
    }

    static func compareBuild(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let right = rhs.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        for index in 0..<max(left.count, right.count) {
            let component = compareInteger(
                index < left.count ? left[index] : "0",
                index < right.count ? right[index] : "0"
            )
            if component != .orderedSame { return component }
        }
        return .orderedSame
    }

    private static func comparePrerelease(_ lhs: [String]?, _ rhs: [String]?) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (left?, right?):
            for index in 0..<max(left.count, right.count) {
                guard index < left.count else { return .orderedAscending }
                guard index < right.count else { return .orderedDescending }
                let leftToken = left[index]
                let rightToken = right[index]
                if leftToken == rightToken { continue }
                let leftIsNumeric = leftToken.allSatisfy(\.isNumber)
                let rightIsNumeric = rightToken.allSatisfy(\.isNumber)
                if leftIsNumeric, rightIsNumeric {
                    return compareInteger(leftToken, rightToken)
                }
                if leftIsNumeric { return .orderedAscending }
                if rightIsNumeric { return .orderedDescending }
                return leftToken.compare(rightToken, options: [.caseInsensitive, .numeric])
            }
            return .orderedSame
        }
    }

    private static func compareInteger(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = normalizedDigits(lhs)
        let right = normalizedDigits(rhs)
        if left.count != right.count {
            return left.count > right.count ? .orderedDescending : .orderedAscending
        }
        return left.compare(right)
    }

    private static func compareFraction(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let count = max(lhs.count, rhs.count)
        return lhs.padding(toLength: count, withPad: "0", startingAt: 0)
            .compare(rhs.padding(toLength: count, withPad: "0", startingAt: 0))
    }

    private static func normalizedDigits(_ value: String) -> String {
        let digits = value.prefix(while: \.isNumber)
        let trimmed = digits.drop(while: { $0 == "0" })
        return trimmed.isEmpty ? "0" : String(trimmed)
    }

    private struct ParsedVersion {
        let core: [String]
        let prerelease: [String]?

        init(_ raw: String) {
            var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if (value.hasPrefix("v") || value.hasPrefix("V")),
               value.dropFirst().first?.isNumber == true {
                value.removeFirst()
            }
            if let firstDigit = value.firstIndex(where: \.isNumber), firstDigit != value.startIndex {
                value = String(value[firstDigit...])
            }
            value = String(value.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: false)[0])
            let pieces = value.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false)
            core = pieces[0].split(separator: ".", omittingEmptySubsequences: false).map {
                let digits = $0.prefix(while: \.isNumber)
                return digits.isEmpty ? "0" : String(digits)
            }
            let tokens = pieces.count > 1
                ? pieces[1].split(whereSeparator: { $0 == "." || $0 == "-" || $0 == "_" })
                    .map { String($0).lowercased() }
                : []
            prerelease = tokens.isEmpty ? nil : tokens
        }
    }
}

fileprivate enum IOPMPrivate {
    static let kIOPMSleepDisabledKey = "SleepDisabled" as CFString

    private static func loadSymbol<T>(_ name: String) -> T? {
        let framework = Bundle(path: "/System/Library/Frameworks/IOKit.framework")
        guard let handle = framework?.executableURL.flatMap({ dlopen($0.path, RTLD_LAZY) }),
              let symbol = dlsym(handle, name) else {
            return nil
        }
        return unsafeBitCast(symbol, to: T.self)
    }

    static let IOPMSetSystemPowerSetting: (@convention(c) (CFString, CFTypeRef) -> IOReturn)? = loadSymbol("IOPMSetSystemPowerSetting")


    static func setSleepDisabled(_ disabled: Bool) -> IOReturn {
        guard let function = IOPMSetSystemPowerSetting else {
            os_log("IOPMSetSystemPowerSetting symbol not found.")
            return kIOReturnUnsupported
        }
        let cfValue: CFTypeRef = disabled ? (kCFBooleanTrue as CFTypeRef) : (kCFBooleanFalse as CFTypeRef)
        return function(kIOPMSleepDisabledKey, cfValue)
    }
}

class Helper: NSObject, HelperProtocol {

    private let logger = Logger(subsystem: "com.shariq.sapphireHelper", category: "Helper")
    private let updateInstallLock = NSLock()
    var client: InstallationClient?
    private let smc: SMC?
    private let sensorCacheLock = NSLock()
    private var sensorCache: [String: Double] = [:]
    private var sensorCacheTimestamp = Date.distantPast
    private let sensorCacheLifetime: TimeInterval = 0.25

    private struct AppliedFanState: Equatable {
        let mode: FanMode
        let speed: Int?
    }
    private let fanStateLock = NSLock()
    private var appliedFanStates: [Int: AppliedFanState] = [:]


    override init() {
        self.smc = SMC()
        super.init()

        if self.smc == nil {
            logger.critical("FATAL ERROR: Could not establish connection to SMC. The helper will not function.")
        } else {
            logger.log("SMC connection successful.")
        }
    }

    deinit {
        logger.log("Helper deinitializing and closing SMC connection.")
        if let smc = smc, let fanCount = smc.getValue("FNum") {
            for i in 0..<Int(fanCount) {
                logger.log("Reverting fan \(i) to automatic mode as helper is deinitializing.")
                _ = smc.setFanMode(i, mode: .automatic)
            }
        }
        _ = smc?.close()
    }

    // MARK: - Sensor & Generic Functions


    func getAllSMCKeys(reply: @escaping ([String]) -> Void) {
        reply(smc?.getAllKeys() ?? [])
    }
    func getSensorValues(keys: [String], reply: @escaping (NSDictionary) -> Void) {
        guard let smc else {
            reply(NSDictionary())
            return
        }

        sensorCacheLock.lock()
        let now = Date()
        let cacheIsFresh = now.timeIntervalSince(sensorCacheTimestamp) < sensorCacheLifetime
        let uniqueKeys = Array(Set(keys))
        let missingKeys = uniqueKeys.filter { !cacheIsFresh || sensorCache[$0] == nil }
        for key in missingKeys {
            sensorCache[key] = smc.getValue(key) ?? -1.0
        }
        sensorCacheTimestamp = now

        let values = NSMutableDictionary(capacity: uniqueKeys.count)
        for key in uniqueKeys {
            values[key] = NSNumber(value: sensorCache[key] ?? -1.0)
        }
        sensorCacheLock.unlock()
        reply(values)
    }

    func getSensorValue(key: String, reply: @escaping (Double) -> Void) {
        getSensorValues(keys: [key]) { values in
            reply((values[key] as? NSNumber)?.doubleValue ?? -1.0)
        }
    }
    func getVersion(reply: @escaping (String) -> Void) {
        reply(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A")
    }
    func getProtocolVersion(reply: @escaping (Int) -> Void) {
        reply(SapphireHelperProtocolVersion)
    }

    func installUpdate(
        newAppPath: String,
        currentAppPath: String,
        expectedVersion: String,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        logger.info("[Helper] installUpdate requested (new=\(newAppPath) current=\(currentAppPath))")

        guard updateInstallLock.try() else {
            completion(false, makeError(code: .generalError, description: "Another Sapphire update is already being installed."))
            return
        }
        defer { updateInstallLock.unlock() }

        func fail(_ message: String, arguments: [String] = []) {
            let error = makeError(code: .generalError, description: message, arguments: arguments)
            logger.error("[Helper] installUpdate failed: \(error.localizedDescription)")
            completion(false, error)
        }

        let fileManager = FileManager.default
        let newURL = URL(fileURLWithPath: newAppPath).standardizedFileURL
        let currentURL = URL(fileURLWithPath: currentAppPath).standardizedFileURL
        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let currentComponents = currentURL.pathComponents
        let applicationsComponents = applicationsURL.pathComponents
        let newValues = try? newURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        let currentValues = try? currentURL.resourceValues(forKeys: [.isSymbolicLinkKey])
        guard !newAppPath.isEmpty,
              newURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame,
              fileManager.fileExists(atPath: newURL.path),
              newValues?.isSymbolicLink != true,
              !currentAppPath.isEmpty,
              currentURL.path != "/",
              newURL != currentURL,
              fileManager.fileExists(atPath: currentURL.path),
              currentValues?.isSymbolicLink != true,
              !expectedVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              currentComponents.count == applicationsComponents.count + 1,
              currentComponents.prefix(applicationsComponents.count).elementsEqual(applicationsComponents),
              Bundle(url: currentURL)?.bundleIdentifier == "com.yuxi.sapphire.local",
              Bundle(url: newURL)?.bundleIdentifier == "com.yuxi.sapphire.local" else {
            fail("Invalid app paths for the update.")
            return
        }

        var currentCode: SecStaticCode?
        var requirement: SecRequirement?
        let validationFlags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode)
        guard SecStaticCodeCreateWithPath(currentURL as CFURL, [], &currentCode) == errSecSuccess,
              let currentCode,
              SecStaticCodeCheckValidity(currentCode, validationFlags, nil) == errSecSuccess,
              SecCodeCopyDesignatedRequirement(currentCode, [], &requirement) == errSecSuccess,
              let requirement else {
            fail("The installed Sapphire signature could not be validated.")
            return
        }

        let currentBundle = Bundle(url: currentURL)
        guard let currentVersion = currentBundle?
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !currentVersion.isEmpty else {
            fail("The installed Sapphire version could not be read.")
            return
        }
        let currentBuild = currentBundle?
            .object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"

        let parent = currentURL.deletingLastPathComponent()
        let transactionID = UUID().uuidString
        let stagingURL = parent.appendingPathComponent(".Sapphire-update-\(transactionID).app")
        do {
            try fileManager.copyItem(at: newURL, to: stagingURL)
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            fail("Could not stage the update: %@", arguments: [error.localizedDescription])
            return
        }

        var stagedCode: SecStaticCode?
        let stagedBundle = Bundle(url: stagingURL)
        let stagedVersion = stagedBundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let stagedBuild = stagedBundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        let marketingComparison = stagedVersion.map {
            HelperSapphireVersionOrdering.compare($0, currentVersion)
        }
        let isMonotonicUpgrade = marketingComparison == .orderedDescending
            || (marketingComparison == .orderedSame
                && HelperSapphireVersionOrdering.compareBuild(stagedBuild, currentBuild) == .orderedDescending)
        guard stagedBundle?.bundleIdentifier == "com.yuxi.sapphire.local",
              stagedVersion == expectedVersion,
              isMonotonicUpgrade,
              SecStaticCodeCreateWithPath(stagingURL as CFURL, [], &stagedCode) == errSecSuccess,
              let stagedCode,
              SecStaticCodeCheckValidity(stagedCode, validationFlags, requirement) == errSecSuccess else {
            try? fileManager.removeItem(at: stagingURL)
            fail("The staged update must be newer than the installed signed release and match its verified version and signature.")
            return
        }

        do {
            _ = try fileManager.replaceItemAt(
                currentURL,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: []
            )
        } catch {
            try? fileManager.removeItem(at: stagingURL)
            fail("The filesystem could not transactionally install the update: %@", arguments: [error.localizedDescription])
            return
        }

        logger.log("[Helper] installUpdate succeeded; new app is in place at \(currentAppPath)")
        completion(true, nil)
    }
    // MARK: - Continuity Microphone driver

    private static let halPluginDirectory = "/Library/Audio/Plug-Ins/HAL"
    private static let micDriverName = "SapphireAudioDriver.driver"
    private static let micRingDirectory = "/Library/Application Support/Sapphire"
    private static let micRingPath = "/Library/Application Support/Sapphire/ContinuityMic.ring"
    private static let micRingByteSize = 80 + 48000 * 2 * 1 * 4

    func installAudioDriver(driverBundlePath: String, reply: @escaping (Bool, String?) -> Void) {
        logger.info("[Helper] installAudioDriver requested (\(driverBundlePath))")
        let fileManager = FileManager.default

        func fail(_ message: String) {
            logger.error("[Helper] installAudioDriver failed: \(message)")
            reply(false, message)
        }

        guard !driverBundlePath.isEmpty,
              (driverBundlePath as NSString).lastPathComponent == Self.micDriverName,
              driverBundlePath.hasPrefix("/"),
              !driverBundlePath.contains(".."),
              fileManager.fileExists(atPath: driverBundlePath) else {
            fail("The audio driver path is not valid.")
            return
        }

        let destination = (Self.halPluginDirectory as NSString).appendingPathComponent(Self.micDriverName)

        do {
            if !fileManager.fileExists(atPath: Self.halPluginDirectory) {
                try fileManager.createDirectory(atPath: Self.halPluginDirectory,
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o755])
            }
            if fileManager.fileExists(atPath: destination) {
                try fileManager.removeItem(atPath: destination)
            }
            try fileManager.copyItem(atPath: driverBundlePath, toPath: destination)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destination)
        } catch {
            fail("Could not install the driver: \(error.localizedDescription)")
            return
        }

        do {
            if !fileManager.fileExists(atPath: Self.micRingDirectory) {
                try fileManager.createDirectory(atPath: Self.micRingDirectory,
                                                withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o755])
            }
            if !fileManager.fileExists(atPath: Self.micRingPath) {
                fileManager.createFile(atPath: Self.micRingPath, contents: nil,
                                       attributes: [.posixPermissions: 0o666])
            }
            let handle = FileHandle(forWritingAtPath: Self.micRingPath)
            try handle?.truncate(atOffset: UInt64(Self.micRingByteSize))
            try handle?.close()
            try fileManager.setAttributes([.posixPermissions: 0o666], ofItemAtPath: Self.micRingPath)
        } catch {
            fail("Could not prepare the microphone buffer: \(error.localizedDescription)")
            return
        }

        let status = runPrivilegedCommand("/bin/launchctl", args: ["kickstart", "-k", "system/com.apple.audio.coreaudiod"])
        if status != 0 {
            logger.warning("[Helper] coreaudiod restart returned \(status); the device may need a reboot")
        }

        logger.log("[Helper] installAudioDriver succeeded")
        reply(true, nil)
    }

    func uninstallAudioDriver(reply: @escaping (Bool, String?) -> Void) {
        let destination = (Self.halPluginDirectory as NSString).appendingPathComponent(Self.micDriverName)
        let fileManager = FileManager.default
        do {
            if fileManager.fileExists(atPath: destination) {
                try fileManager.removeItem(atPath: destination)
            }
            if fileManager.fileExists(atPath: Self.micRingPath) {
                try fileManager.removeItem(atPath: Self.micRingPath)
            }
        } catch {
            reply(false, "Could not remove the driver: \(error.localizedDescription)")
            return
        }
        _ = runPrivilegedCommand("/bin/launchctl", args: ["kickstart", "-k", "system/com.apple.audio.coreaudiod"])
        logger.log("[Helper] uninstallAudioDriver succeeded")
        reply(true, nil)
    }

    // MARK: - Fan Control Functions
    func getFanCount(reply: @escaping (Int) -> Void) {
        guard let smc else {
            reply(0)
            return
        }

        let probed = probeFanCount(using: smc)
        if let count = smc.getValue("FNum").map({ Int($0) }), count > 0 {
            reply(max(count, probed))
            return
        }
        reply(probed)
    }

    private func probeFanCount(using smc: SMC) -> Int {
        var probed = 0
        for index in 0..<8 {
            let hasFan = smc.keyExists("F\(index)Mn")
                || smc.keyExists("F\(index)Mx")
                || smc.keyExists("F\(index)Ac")
                || smc.keyExists("F\(index)Tg")
            if hasFan {
                probed = index + 1
            } else if probed > 0 {
                break
            } else {
                break
            }
        }
        return probed
    }

    func getFanInfo(fanIndex: Int, reply: @escaping (FanInfo?) -> Void) {
        guard let smc = smc else { reply(nil); return }
        let hardwareName = smc.getStringValue("F\(fanIndex)ID")
        let name = hardwareName ?? (fanIndex == 0 ? "Left fan" : fanIndex == 1 ? "Right fan" : "Fan \(fanIndex)")
        let minRPM = Int(smc.getValue("F\(fanIndex)Mn") ?? 0)
        let maxRPM = Int(smc.getValue("F\(fanIndex)Mx") ?? 0)
        let currentRPM = Int(smc.getValue("F\(fanIndex)Ac") ?? 0)
        guard minRPM > 0 || maxRPM > 0 || currentRPM > 0 || smc.keyExists("F\(fanIndex)Ac") else {
            reply(nil)
            return
        }
        reply(FanInfo(
            id: fanIndex,
            name: name.isEmpty ? "Fan \(fanIndex)" : name,
            minRPM: minRPM,
            maxRPM: max(maxRPM, minRPM),
            currentRPM: currentRPM,
            usesDefaultName: hardwareName?.isEmpty != false
        ))
    }
    func setFanMode(fanIndex: Int, mode: UInt8, reply: @escaping (Error?) -> Void) {
        guard let smc = smc else { reply(makeError(code: .smcOpenFailed, description: "SMC not connected.")); return }
        let targetMode: FanMode = mode == 0 ? .automatic : .forced
        let requestedState = AppliedFanState(mode: targetMode, speed: targetMode == .automatic ? 0 : nil)

        fanStateLock.lock()
        let alreadyApplied = appliedFanStates[fanIndex] == requestedState
        fanStateLock.unlock()
        if alreadyApplied {
            reply(nil)
            return
        }

        logger.log("Request to set fan \(fanIndex) to \(targetMode == .automatic ? "AUTO" : "FORCED") mode.")
        let modeResult = smc.setFanMode(fanIndex, mode: targetMode)
        let speedResult = targetMode == .automatic ? smc.setFanSpeed(fanIndex, speed: 0) : kIOReturnSuccess
        if modeResult == kIOReturnSuccess && speedResult == kIOReturnSuccess {
            fanStateLock.lock()
            appliedFanStates[fanIndex] = requestedState
            fanStateLock.unlock()
            reply(nil)
        } else {
            reply(makeError(code: .smcWriteFailed, description: "Failed to set fan mode."))
        }
    }
    func setFanTargetSpeed(fanIndex: Int, speed: Int, reply: @escaping (Error?) -> Void) {
        guard let smc = smc else { reply(makeError(code: .smcOpenFailed, description: "SMC not connected.")); return }
        fanStateLock.lock()
        let alreadyApplied = appliedFanStates[fanIndex] == AppliedFanState(mode: .forced, speed: speed)
        fanStateLock.unlock()
        if alreadyApplied {
            reply(nil)
            return
        }

        let result = smc.setFanSpeed(fanIndex, speed: speed)
        if result == kIOReturnSuccess {
            fanStateLock.lock()
            appliedFanStates[fanIndex] = AppliedFanState(mode: .forced, speed: speed)
            fanStateLock.unlock()
        }
        reply(result == kIOReturnSuccess ? nil : makeError(code: .smcWriteFailed, description: "Failed to write F%@Tg.", arguments: [String(fanIndex)]))
    }
    func setFanToConstantRPM(fanIndex: Int, speed: Int, reply: @escaping (Error?) -> Void) {
        logger.log("Request to set fan \(fanIndex) to a constant \(speed) RPM.")
        guard let smc = smc else { logger.error("SMC connection not available."); reply(makeError(code: .smcOpenFailed, description: "SMC not connected.")); return }

        fanStateLock.lock()
        let alreadyApplied = appliedFanStates[fanIndex] == AppliedFanState(mode: .forced, speed: speed)
        fanStateLock.unlock()
        if alreadyApplied {
            reply(nil)
            return
        }
        logger.log("Step 1/2: Setting fan \(fanIndex) to FORCED mode.")
        let modeResult = smc.setFanMode(fanIndex, mode: .forced)
        if modeResult != kIOReturnSuccess {
            logger.error("Failed to set fan mode to forced for fan \(fanIndex). Aborting. Error code: \(modeResult)"); reply(makeError(code: .smcWriteFailed, description: "Failed to set fan to manual mode.")); return
        }
        logger.log("Step 2/2: Setting fan \(fanIndex) target speed to \(speed) RPM.")
        let speedResult = smc.setFanSpeed(fanIndex, speed: speed)
        if speedResult != kIOReturnSuccess {
            logger.error("Failed to set fan target speed for fan \(fanIndex). Error code: \(speedResult)"); _ = smc.setFanMode(fanIndex, mode: .automatic); reply(makeError(code: .smcWriteFailed, description: "Failed to write F%@Tg.", arguments: [String(fanIndex)])); return
        }
        fanStateLock.lock()
        appliedFanStates[fanIndex] = AppliedFanState(mode: .forced, speed: speed)
        fanStateLock.unlock()
        logger.log("Successfully set fan \(fanIndex) to \(speed) RPM."); reply(nil)
    }

    func createAggregateDevice(subDeviceUIDs: [String], masterDeviceUID: String, reply: @escaping (UInt32) -> Void) {
        guard let masterDeviceID = getDeviceID(from: masterDeviceUID),
              let masterSampleRate = getSampleRate(from: masterDeviceID) else {
            reply(0)
            return
        }

        let subDeviceList = subDeviceUIDs.map { uid -> [String: Any] in
            var subDeviceDict: [String: Any] = [kAudioSubDeviceUIDKey: uid as CFString]
            if uid != masterDeviceUID { subDeviceDict[kAudioSubDeviceDriftCompensationKey] = 1 }
            return subDeviceDict
        }

        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Sapphire Multi-Output",
            kAudioAggregateDeviceUIDKey: "com.shariq.sapphire.multi-output-device",
            kAudioAggregateDeviceSubDeviceListKey: subDeviceList,
            kAudioAggregateDeviceMasterSubDeviceKey: masterDeviceUID as CFString,
            kAudioAggregateDeviceIsStackedKey: 1
        ]

        var aggregateDeviceID: AudioDeviceID = 0
        let createStatus = AudioHardwareCreateAggregateDevice(description as CFDictionary, &aggregateDeviceID)

        guard createStatus == noErr, aggregateDeviceID != 0 else {
            reply(0)
            return
        }

        var mutableSampleRate = masterSampleRate
        var propertySize = UInt32(MemoryLayout.size(ofValue: mutableSampleRate))
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let setRateStatus = AudioObjectSetPropertyData(aggregateDeviceID, &address, 0, nil, propertySize, &mutableSampleRate)

        if setRateStatus != noErr {
            _ = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            reply(0)
            return
        }

        reply(aggregateDeviceID)
    }

    func destroyAggregateDevice(id: UInt32, reply: @escaping (Bool) -> Void) {
        let status = AudioHardwareDestroyAggregateDevice(id)
        reply(status == noErr)
    }

    func setAggregateSubDeviceVolume(aggregateDeviceID: UInt32, subDeviceUID: String, volume: Float, reply: @escaping (Bool) -> Void) {
        guard let subDeviceID = findSubDeviceID(in: aggregateDeviceID, for: subDeviceUID) else {
            reply(false)
            return
        }

        var mutableVolume = volume
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyVolumeScalar, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(subDeviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutableVolume)), &mutableVolume)
        reply(status == noErr)
    }

    func setAggregateSubDeviceBalance(aggregateDeviceID: UInt32, subDeviceUID: String, balance: Float, reply: @escaping (Bool) -> Void) {
        guard let subDeviceID = findSubDeviceID(in: aggregateDeviceID, for: subDeviceUID) else {
            reply(false)
            return
        }

        var mutableBalance = balance
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStereoPan, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(subDeviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutableBalance)), &mutableBalance)
        reply(status == noErr)
    }

    func setAggregateSubDeviceDelay(aggregateDeviceID: UInt32, subDeviceUID: String, delayInSeconds: Float, reply: @escaping (Bool) -> Void) {
        guard let subDeviceID = findSubDeviceID(in: aggregateDeviceID, for: subDeviceUID),
              let sampleRate = getSampleRate(from: subDeviceID) else {
            reply(false)
            return
        }

        let delayInFrames = UInt32(Double(delayInSeconds) * sampleRate)
        var mutableDelay = delayInFrames

        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyLatency, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectSetPropertyData(subDeviceID, &address, 0, nil, UInt32(MemoryLayout.size(ofValue: mutableDelay)), &mutableDelay)
        reply(status == noErr)
    }

    private func findSubDeviceID(in aggregateID: AudioDeviceID, for targetUID: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioAggregateDevicePropertyFullSubDeviceList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(aggregateID, &address, 0, nil, &propertySize) == noErr, propertySize > 0 else {
            return nil
        }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var subDeviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(aggregateID, &address, 0, nil, &propertySize, &subDeviceIDs) == noErr else {
            return nil
        }

        for id in subDeviceIDs {
            if getDeviceUID(from: id) == targetUID {
                return id
            }
        }

        return nil
    }

    private func getDeviceUID(from deviceID: AudioDeviceID) -> String? {
        var deviceUID: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        var uidAddress = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyDeviceUID, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)

        if AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, &deviceUID) == noErr {
            return deviceUID as String
        }
        return nil
    }

    private func getDeviceID(from uid: String) -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var propertySize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize) == noErr else { return nil }

        let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs) == noErr else { return nil }

        for deviceID in deviceIDs {
            if getDeviceUID(from: deviceID) == uid {
                return deviceID
            }
        }
        return nil
    }

    private func getSampleRate(from deviceID: AudioDeviceID) -> Double? {
        var sampleRate: Double = 0
        var propertySize = UInt32(MemoryLayout<Double>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyNominalSampleRate, mScope: kAudioObjectPropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)

        if AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &sampleRate) == noErr {
            return sampleRate
        }
        return nil
    }

    private func runPrivilegedCommand(_ path: String, args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = path
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8) {
                    logger.error("Command failed with output: \(output)")
                }
            }

            return task.terminationStatus
        } catch {
            logger.error("Failed to run command: \(error.localizedDescription)")
            return -1
        }
    }

    func preventSystemSleep(reply: @escaping (Error?) -> Void) {
        logger.log("Client requested to prevent system sleep (clamshell mode).")
        let result = IOPMPrivate.setSleepDisabled(true)
        if result == kIOReturnSuccess {
            reply(nil)
        } else {
            let errorDescription = "Failed to disable system sleep via IOKit. Error: \(result)"
            logger.error("\(errorDescription)")
            reply(makeError(code: .generalError, description: "Failed to disable system sleep via IOKit. Error: %@", arguments: [String(result)]))
        }
    }

    func allowSystemSleep(reply: @escaping (Error?) -> Void) {
        logger.log("Client requested to allow system sleep.")
        let result = IOPMPrivate.setSleepDisabled(false)
        if result == kIOReturnSuccess {
            reply(nil)
        } else {
            let errorDescription = "Failed to enable system sleep via IOKit. Error: \(result)"
            logger.error("\(errorDescription)")
            reply(makeError(code: .generalError, description: "Failed to enable system sleep via IOKit. Error: %@", arguments: [String(result)]))
        }
    }

    // MARK: - Focus Website Blocking (/etc/hosts)

    private static let hostsMarkerStart = "# >>> Sapphire Focus Block >>>"
    private static let hostsMarkerEnd = "# <<< Sapphire Focus Block <<<"

    func writeHostsEntries(_ lines: [String], reply: @escaping (Bool) -> Void) {
        reply(rewriteHosts(replacingWith: lines))
    }

    func removeHostsEntries(reply: @escaping (Bool) -> Void) {
        reply(rewriteHosts(replacingWith: []))
    }

    private func rewriteHosts(replacingWith entries: [String]) -> Bool {
        let path = "/etc/hosts"
        let current = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        var lines = current.components(separatedBy: "\n")
        if let start = lines.firstIndex(of: Self.hostsMarkerStart),
           let end = lines[start...].firstIndex(of: Self.hostsMarkerEnd) {
            lines.removeSubrange(start...end)
        }
        if entries.count > 2 {
            lines.append(contentsOf: entries)
        }
        while let last = lines.last, last.isEmpty {
            lines.removeLast()
        }
        let newContent = lines.joined(separator: "\n") + "\n"
        guard newContent != current else { return true }

        do {
            try newContent.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            return false
        }

        _ = runPrivilegedCommand("/usr/bin/dscacheutil", args: ["-flushcache"])
        _ = runPrivilegedCommand("/usr/bin/killall", args: ["-HUP", "mDNSResponder"])
        return true
    }
}
