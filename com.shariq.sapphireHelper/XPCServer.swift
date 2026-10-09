//
//  XPCServer.swift
//  Sapphire
//
//  Created by Shariq Charolia on 2025-10-02
//

import Foundation

class XPCServer: NSObject {

    internal static let shared = XPCServer()
    // Listener initialization is serialized on main.
    private var listener: NSXPCListener?
    private let helper = Helper()

    private func onMain(_ action: () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.sync(execute: action)
        }
    }

    internal func start() {
        onMain {
            guard listener == nil else { return }

            let newListener = NSXPCListener(machServiceName: Constant.helperMachLabel)
            newListener.delegate = self
            listener = newListener
            newListener.resume()
            NSLog("[SMJBS]: XPC listener resumed for \(Constant.helperMachLabel)")
        }
    }

    private func connectionInterruptionHandler(pid: Int32) {
        NSLog("[SMJBS]: Client connection interrupted (pid=\(pid)).")
    }

    private func connectionInvalidationHandler(pid: Int32) {
        NSLog("[SMJBS]: Client connection invalidated (pid=\(pid)).")
    }

    private func isValidClient(forConnection connection: NSXPCConnection) -> Bool {
        do {
            return try CodesignCheck.isSapphireClient(auditToken: connection.auditToken)
        } catch {
            NSLog("[SMJBS]: Code signing check failed with error: \(error)")
            return false
        }
    }
}

extension XPCServer: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        NSLog("[SMJBS]: New connection received. Validating client...")

        if (!isValidClient(forConnection: newConnection)) {
            NSLog("[SMJBS]: Client is NOT valid. Rejecting connection.")
            return false
        }

        NSLog("[SMJBS]: Client is valid. Accepting connection.")

        let interface = NSXPCInterface(with: HelperProtocol.self)
        interface.setClasses(
            NSSet(array: [FanInfo.self, NSNull.self]) as! Set<AnyHashable>,
            for: #selector(HelperProtocol.getFanInfo(fanIndex:reply:)),
            argumentIndex: 0,
            ofReply: true
        )
        newConnection.exportedInterface = interface
        newConnection.exportedObject = helper

        newConnection.remoteObjectInterface = NSXPCInterface(with: InstallationClient.self)

        let pid = newConnection.processIdentifier
        newConnection.interruptionHandler = { [weak self] in
            self?.connectionInterruptionHandler(pid: pid)
        }
        newConnection.invalidationHandler = { [weak self] in
            self?.connectionInvalidationHandler(pid: pid)
        }

        // Serialize listener connection setup.
        onMain {
            helper.client = newConnection.remoteObjectProxy as? InstallationClient
            newConnection.resume()
        }
        return true
    }
}