//
//  HelperProtocol.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-02
//

import Foundation

let SapphireHelperProtocolVersion: Int = 14

@objc protocol HelperProtocol {
    func getAllSMCKeys(reply: @escaping ([String]) -> Void)
    func getSensorValues(keys: [String], reply: @escaping (NSDictionary) -> Void)
    func getVersion(reply: @escaping (String) -> Void)
    func getProtocolVersion(reply: @escaping (Int) -> Void)
    func createAggregateDevice(subDeviceUIDs: [String], masterDeviceUID: String, reply: @escaping (UInt32) -> Void)
    func destroyAggregateDevice(id: UInt32, reply: @escaping (Bool) -> Void)
    func setAggregateSubDeviceVolume(aggregateDeviceID: UInt32, subDeviceUID: String, volume: Float, reply: @escaping (Bool) -> Void)

    func setAggregateSubDeviceBalance(aggregateDeviceID: UInt32, subDeviceUID: String, balance: Float, reply: @escaping (Bool) -> Void)
    func setAggregateSubDeviceDelay(aggregateDeviceID: UInt32, subDeviceUID: String, delayInSeconds: Float, reply: @escaping (Bool) -> Void)

    func preventSystemSleep(reply: @escaping (Error?) -> Void)
    func allowSystemSleep(reply: @escaping (Error?) -> Void)

    func writeHostsEntries(_ lines: [String], reply: @escaping (Bool) -> Void)
    func removeHostsEntries(reply: @escaping (Bool) -> Void)

    func installUpdate(
        newAppPath: String,
        currentAppPath: String,
        expectedVersion: String,
        completion: @escaping (Bool, Error?) -> Void
    )

    func installAudioDriver(driverBundlePath: String, reply: @escaping (Bool, String?) -> Void)
    func uninstallAudioDriver(reply: @escaping (Bool, String?) -> Void)

}