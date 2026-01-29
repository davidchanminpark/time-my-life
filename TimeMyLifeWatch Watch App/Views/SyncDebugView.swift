//
//  SyncDebugView.swift
//  TimeMyLifeWatch Watch App
//

import SwiftUI
import WatchConnectivity

// watchReceivedMessage is defined in WatchConnectivitySyncService.swift

struct SyncDebugView: View {
    @State private var receivedMessages: [String] = []
    @State private var sessionState = "Unknown"
    @State private var isReachable = false
    @State private var lastSyncRequest = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sync Debug")
                    .font(.headline)

                HStack {
                    Text("Status:")
                    Spacer()
                    Text(sessionState)
                        .foregroundColor(sessionState == "Activated" ? .green : .red)
                }
                .font(.caption)

                HStack {
                    Text("Reachable:")
                    Spacer()
                    Image(systemName: isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isReachable ? .green : .red)
                }
                .font(.caption)

                Button("Request Full Sync") {
                    requestFullSync()
                }
                .font(.caption)
                .buttonStyle(.bordered)

                if !lastSyncRequest.isEmpty {
                    Text(lastSyncRequest)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider()

                Text("Received Messages:")
                    .font(.caption)
                    .bold()

                if receivedMessages.isEmpty {
                    Text("No messages yet...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(receivedMessages.indices, id: \.self) { index in
                        Text(receivedMessages[index])
                            .font(.caption2)
                            .padding(4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
        }
        .onAppear {
            updateStatus()
            setupMessageListener()

            // Refresh every 2 seconds
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                updateStatus()
            }
        }
    }

    private func updateStatus() {
        let session = WCSession.default

        switch session.activationState {
        case .activated:
            sessionState = "Activated"
        case .inactive:
            sessionState = "Inactive"
        case .notActivated:
            sessionState = "Not Activated"
        @unknown default:
            sessionState = "Unknown"
        }

        isReachable = session.isReachable
    }

    private func setupMessageListener() {
        // DON'T set up our own delegate - let the main app's WatchConnectivitySyncService handle it
        // Just listen for messages from the app's sync service

        // Listen for messages from delegate
        NotificationCenter.default.addObserver(
            forName: .watchReceivedMessage,
            object: nil,
            queue: .main
        ) { notification in
            if let message = notification.userInfo?["message"] as? String {
                receivedMessages.insert("📥 \(message)", at: 0)
                if receivedMessages.count > 10 {
                    receivedMessages.removeLast()
                }
            }
        }
    }

    private func requestFullSync() {
        lastSyncRequest = "Requesting full sync..."

        let session = WCSession.default
        let message: [String: Any] = [
            "type": "fullSyncRequest",
            "timestamp": Date().timeIntervalSince1970
        ]

        session.transferUserInfo(message)
        lastSyncRequest = "✅ Full sync requested at \(Date().formatted(date: .omitted, time: .standard))"

        #if DEBUG
        print("📡 Watch: Requesting full sync from iPhone")
        #endif
    }
}

// Simple delegate to handle incoming messages (kept for reference but not used)
class DebugSessionDelegate: NSObject, WCSessionDelegate {
    static let shared = DebugSessionDelegate()

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📡 Watch: Session activated - \(activationState.rawValue)")
        if let error = error {
            print("❌ Watch: Activation error: \(error)")
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        print("📥 Watch: Received message: \(message)")
        let msg = "Message: \(message.keys.joined(separator: ", "))"
        NotificationCenter.default.post(
            name: .watchReceivedMessage,
            object: nil,
            userInfo: ["message": msg]
        )
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        print("📥 Watch: Received userInfo: \(userInfo)")
        let msg = "UserInfo: \(userInfo.keys.joined(separator: ", "))"
        NotificationCenter.default.post(
            name: .watchReceivedMessage,
            object: nil,
            userInfo: ["message": msg]
        )
    }
}
