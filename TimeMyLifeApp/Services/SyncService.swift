//
//  SyncService.swift
//  TimeMyLifeApp
//

import Foundation

/// Types of models that can be synced
public enum SyncModelType: String, Codable {
    case activity
    case scheduledDay
    case timeEntry
    case activeTimer
    case goal
}

/// Sync action types
public enum SyncAction: String, Codable {
    case create
    case update
    case delete
}

/// Message wrapper for syncing
public struct SyncMessage: Codable {
    let action: SyncAction
    let modelType: SyncModelType
    let data: Data
    let timestamp: Date
    let modelId: String

    init<T: Codable & Identifiable>(action: SyncAction, modelType: SyncModelType, model: T) throws where T.ID == UUID {
        self.action = action
        self.modelType = modelType
        self.data = try JSONEncoder().encode(model)
        self.timestamp = Date()
        self.modelId = model.id.uuidString
    }

    init(action: SyncAction, modelType: SyncModelType, modelId: UUID) {
        self.action = action
        self.modelType = modelType
        self.data = Data()
        self.timestamp = Date()
        self.modelId = modelId.uuidString
    }
}

/// Protocol for syncing data between devices
@MainActor
public protocol SyncService: AnyObject {
    /// Send a model to the counterpart device
    func syncModel<T: Codable & Identifiable>(_ model: T, type: SyncModelType, action: SyncAction) async throws where T.ID == UUID

    /// Send delete notification to counterpart
    func syncDelete(id: UUID, type: SyncModelType) async throws

    /// Request full sync from counterpart
    func requestFullSync() async throws

    /// Callback when model is received from counterpart
    var onSyncMessageReceived: ((SyncMessage) -> Void)? { get set }

    /// Check if counterpart device is reachable
    var isCounterpartReachable: Bool { get }

    /// Activate the sync service
    func activate()
}
