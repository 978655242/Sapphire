//
//  ProcessRunner.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2026-08-30

import Foundation
import Darwin

enum ProcessRunner {

    struct Result: Sendable {
        let stdoutData: Data
        var exitCode: Int32

        var stdout: String { String(data: stdoutData, encoding: .utf8) ?? "" }
        var succeeded: Bool { exitCode == 0 }
    }

    // MARK: - Core synchronous runner

    @discardableResult
    static func runSync(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval? = nil
    ) -> Result? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        var collected = Data()
        let bufferLock = NSLock()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            bufferLock.lock()
            collected.append(chunk)
            bufferLock.unlock()
        }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        var timeoutItem: DispatchWorkItem?
        if let timeout {
            let item = DispatchWorkItem { [weak process] in
                guard let process, process.isRunning else { return }
                process.terminate()
                let processIdentifier = process.processIdentifier
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [weak process] in
                    guard let process, process.isRunning else { return }
                    Darwin.kill(processIdentifier, SIGKILL)
                }
            }
            timeoutItem = item
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: item)
        }
        process.waitUntilExit()
        timeoutItem?.cancel()
        let tail = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        bufferLock.lock()
        collected.append(tail)
        bufferLock.unlock()

        return Result(
            stdoutData: collected,
            exitCode: process.terminationStatus
        )
    }

    // MARK: - Async wrapper

    static func run(
        executablePath: String,
        arguments: [String],
        timeout: TimeInterval? = nil
    ) async -> Result? {
        await Task.detached(priority: .utility) {
            runSync(executablePath: executablePath, arguments: arguments, timeout: timeout)
        }.value
    }

    // MARK: - Fire-and-forget

    static func runDetached(executablePath: String, arguments: [String]) {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    // MARK: - AppleScript convenience

    static func runAppleScript(
        _ script: String,
        extraArguments: [String] = [],
        timeout: TimeInterval? = 5
    ) async -> String? {
        let result = await run(
            executablePath: "/usr/bin/osascript",
            arguments: ["-e", script] + extraArguments,
            timeout: timeout
        )
        guard let result, result.succeeded else { return nil }
        let trimmed = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func runAppleScriptBool(_ script: String, timeout: TimeInterval? = 5) async -> Bool {
        await runAppleScript(script, timeout: timeout)?.lowercased() == "true"
    }
}