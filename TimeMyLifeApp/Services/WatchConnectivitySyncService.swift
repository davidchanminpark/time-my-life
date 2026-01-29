//
//  WatchConnectivitySyncService.swift
//  TimeMyLifeApp
//

import Foundation
import WatchConnectivity

/// WatchConnectivity-based sync service for iOS ↔ watchOS communication
@MainActor
public class WatchConnectivitySyncService: NSObject, SyncService {
    // MARK: - Properties

    private let session: WCSession
    private var messageQueue: [SyncMessage] = []
    private let maxQueueSize = 100

    public var onSyncMessageReceived: ((SyncMessage) -> Void)?

    public var isCounterpartReachable: Bool {
        #if os(iOS)
        return session.isReachable
        #else
        return session.isReachable
        #endif
    }

    // MARK: - Initialization

    public override init() {
        self.session = WCSession.default
        super.init()
    }

    // MARK: - SyncService Protocol

    public func activate() {
        guard WCSession.isSupported() else {
            print("⚠️ WatchConnectivity is not supported on this device")
            return
        }

        session.delegate = self
        session.activate()

        #if DEBUG
        print("📡 WatchConnectivity activated")
        #endif
    }

    public func syncModel<T: Codable & Identifiable>(_ model: T, type: SyncModelType, action: SyncAction) async throws where T.ID == UUID {
        let message = try SyncMessage(action: action, modelType: type, model: model)
        try await sendMessage(message)
    }

    public func syncDelete(id: UUID, type: SyncModelType) async throws {
        let message = SyncMessage(action: .delete, modelType: type, modelId: id)
        try await sendMessage(message)
    }

    public func requestFullSync() async throws {
        let message: [String: Any] = [
            "type": "fullSyncRequest",
            "timestamp": Date()
        ]

        if session.isReachable {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                session.sendMessage(message, replyHandler: { _ in
                    continuation.resume()
                }, errorHandler: { error in
                    continuation.resume(throwing: error)
                })
            }
        } else {
            // Queue for background transfer
            session.transferUserInfo(message)
        }

        #if DEBUG
        print("📡 Full sync requested")
        #endif
    }

    // MARK: - Private Helpers

    private func sendMessage(_ syncMessage: SyncMessage) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let messageData = try encoder.encode(syncMessage)
        let message: [String: Any] = [
            "type": "sync",
            "data": messageData
        ]

        // Check session state before sending
        guard session.activationState == .activated else {
            throw NSError(domain: "WatchConnectivity", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Session not activated"])
        }

        if session.isReachable {
            // Try immediate message first
            do {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    session.sendMessage(message, replyHandler: { _ in
                        #if DEBUG
                        print("✅ Sync message sent: \(syncMessage.modelType.rawValue) - \(syncMessage.action.rawValue)")
                        #endif
                        continuation.resume()
                    }, errorHandler: { error in
                        print("❌ sendMessage failed: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    })
                }
            } catch {
                // Fallback to background transfer if sendMessage fails
                print("⚠️ Falling back to background transfer")
                queueMessage(syncMessage)
                session.transferUserInfo(message)
            }
        } else {
            // Queue for background transfer
            queueMessage(syncMessage)
            session.transferUserInfo(message)

            #if DEBUG
            print("📦 Message queued for background transfer: \(syncMessage.modelType.rawValue)")
            #endif
        }
    }

    private func queueMessage(_ message: SyncMessage) {
        messageQueue.append(message)

        // Limit queue size
        if messageQueue.count > maxQueueSize {
            messageQueue.removeFirst(messageQueue.count - maxQueueSize)
            #if DEBUG
            print("⚠️ Message queue exceeded max size, trimming old messages")
            #endif
        }
    }

    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String else { return }

        switch type {
        case "sync":
            handleSyncMessage(message)
        case "fullSyncRequest":
            handleFullSyncRequest()
        default:
            #if DEBUG
            print("⚠️ Unknown message type: \(type)")
            #endif
        }
    }

    private func handleSyncMessage(_ message: [String: Any]) {
        guard let messageData = message["data"] as? Data else {
            print("❌ Invalid sync message data")
            return
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let syncMessage = try decoder.decode(SyncMessage.self, from: messageData)

            #if DEBUG
            print("📥 Received sync message: \(syncMessage.modelType.rawValue) - \(syncMessage.action.rawValue)")
            #endif

            onSyncMessageReceived?(syncMessage)
        } catch {
            print("❌ Failed to decode sync message: \(error)")
        }
    }

    private func handleFullSyncRequest() {
        #if DEBUG
        print("📥 Received full sync request - sending all data")
        #endif

        // Notify that a full sync was requested
        NotificationCenter.default.post(name: .fullSyncRequested, object: nil)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivitySyncService: WCSessionDelegate {
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {
        #if DEBUG
        print("📡 WCSession became inactive")
        #endif
    }

    public func sessionDidDeactivate(_ session: WCSession) {
        #if DEBUG
        print("📡 WCSession deactivated, reactivating...")
        #endif
        session.activate()
    }
    #endif

    public func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WCSession activation failed: \(error.localizedDescription)")
            return
        }

        #if DEBUG
        switch activationState {
        case .activated:
            print("✅ WCSession activated")
        case .inactive:
            print("⚠️ WCSession inactive")
        case .notActivated:
            print("⚠️ WCSession not activated")
        @unknown default:
            print("⚠️ WCSession unknown state")
        }
        #endif
    }

    public func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        #if DEBUG
        print("📥 Received message (didReceiveMessage): \(message.keys.joined(separator: ", "))")
        #endif

        Task { @MainActor in
            handleReceivedMessage(message)

            // Notify debug view
            NotificationCenter.default.post(
                name: .watchReceivedMessage,
                object: nil,
                userInfo: ["message": "Message: \(message.keys.joined(separator: ", "))"]
            )
        }
    }

    public func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        #if DEBUG
        print("📥 Received userInfo (didReceiveUserInfo): \(userInfo.keys.joined(separator: ", "))")
        #endif

        Task { @MainActor in
            handleReceivedMessage(userInfo)

            // Notify debug view
            NotificationCenter.default.post(
                name: .watchReceivedMessage,
                object: nil,
                userInfo: ["message": "UserInfo: \(userInfo.keys.joined(separator: ", "))"]
            )
        }
    }

    #if os(iOS)
    public func sessionReachabilityDidChange(_ session: WCSession) {
        #if DEBUG
        print("📡 Watch reachability changed: \(session.isReachable ? "reachable" : "not reachable")")
        #endif
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let timeEntryDidSync = Notification.Name("timeEntryDidSync")
    static let activityDidSync = Notification.Name("activityDidSync")
    static let fullSyncRequested = Notification.Name("fullSyncRequested")
    static let watchReceivedMessage = Notification.Name("watchReceivedMessage")
}
