//
//  WatchConnectivityDebugView.swift
//  TimeMyLifeApp
//

import SwiftUI
import WatchConnectivity

/// Debug view to test WatchConnectivity status and send test messages
struct WatchConnectivityDebugView: View {
    let syncService: WatchConnectivitySyncService

    @State private var isSupported = false
    @State private var activationState: WCSessionActivationState = .notActivated
    @State private var isPaired = false
    @State private var isWatchAppInstalled = false
    @State private var isReachable = false
    @State private var lastMessage = ""

    var body: some View {
        List {
            Section("WatchConnectivity Status") {
                HStack {
                    Text("Supported")
                    Spacer()
                    Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isSupported ? .green : .red)
                }

                HStack {
                    Text("Activation State")
                    Spacer()
                    Text(activationStateString)
                        .foregroundColor(activationState == .activated ? .green : .orange)
                }

                #if os(iOS)
                HStack {
                    Text("Watch Paired")
                    Spacer()
                    Image(systemName: isPaired ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isPaired ? .green : .red)
                }

                HStack {
                    Text("Watch App Installed")
                    Spacer()
                    Image(systemName: isWatchAppInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isWatchAppInstalled ? .green : .red)
                }
                #endif

                HStack {
                    Text("Reachable")
                    Spacer()
                    Image(systemName: isReachable ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isReachable ? .green : .red)
                }
            }

            Section("Actions") {
                Button("Refresh Status") {
                    updateStatus()
                }

                Button("Send Test Message") {
                    sendTestMessage()
                }
                .disabled(!isReachable)
            }

            if !lastMessage.isEmpty {
                Section("Last Result") {
                    Text(lastMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Troubleshooting") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If not working:")
                        .font(.headline)

                    Text("1. Make sure both apps are running")
                    Text("2. On simulator: pair watch in Xcode")
                    Text("3. On real devices: watch must be paired via iPhone")
                    Text("4. Try force quitting and relaunching both apps")
                    Text("5. Check console for WatchConnectivity logs")
                }
                .font(.caption)
            }
        }
        .navigationTitle("WatchConnectivity Debug")
        .onAppear {
            updateStatus()

            // Refresh status every 2 seconds
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                updateStatus()
            }
        }
    }

    private var activationStateString: String {
        switch activationState {
        case .activated: return "Activated"
        case .inactive: return "Inactive"
        case .notActivated: return "Not Activated"
        @unknown default: return "Unknown"
        }
    }

    private func updateStatus() {
        let session = WCSession.default

        isSupported = WCSession.isSupported()
        activationState = session.activationState
        isReachable = session.isReachable

        #if os(iOS)
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
        #endif
    }

    private func sendTestMessage() {
        lastMessage = "Sending test message..."

        Task {
            do {
                // First try a simple message without encoding
                let session = WCSession.default

                // Check session state
                guard session.activationState == .activated else {
                    await MainActor.run {
                        lastMessage = "❌ Session not activated: \(session.activationState.rawValue)"
                    }
                    return
                }

                #if os(iOS)
                guard session.isPaired else {
                    await MainActor.run {
                        lastMessage = "❌ Watch not paired"
                    }
                    return
                }

                guard session.isWatchAppInstalled else {
                    await MainActor.run {
                        lastMessage = "❌ Watch app not installed"
                    }
                    return
                }
                #endif

                // Try transferUserInfo (more reliable)
                let testMessage: [String: Any] = [
                    "type": "test",
                    "timestamp": Date().timeIntervalSince1970,
                    "message": "Hello from iOS"
                ]

                let transfer = session.transferUserInfo(testMessage)

                await MainActor.run {
                    lastMessage = "✅ Message queued for transfer at \(Date().formatted(date: .omitted, time: .standard))\nTransfer: \(transfer.isTransferring ? "transferring" : "pending")"
                }

            } catch {
                await MainActor.run {
                    lastMessage = "❌ Failed: \(error.localizedDescription)"
                }
            }
        }
    }
}
