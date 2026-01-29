//
//  SettingsView.swift
//  TimeMyLifeApp
//

import SwiftUI

struct SettingsView: View {
    let dataService: DataService
    let syncService: WatchConnectivitySyncService?

    init(dataService: DataService, syncService: WatchConnectivitySyncService? = nil) {
        self.dataService = dataService
        self.syncService = syncService
    }

    var body: some View {
        NavigationStack {
            List {
                Section("General") {
                    Text("Settings coming soon")
                }

                if let syncService = syncService {
                    Section("Sync") {
                        NavigationLink {
                            WatchConnectivityDebugView(syncService: syncService)
                        } label: {
                            HStack {
                                Label("WatchConnectivity Debug", systemImage: "applewatch")
                                Spacer()
                                if syncService.isCounterpartReachable {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
