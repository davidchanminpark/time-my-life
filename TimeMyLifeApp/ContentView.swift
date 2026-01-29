//
//  ContentView.swift
//  TimeMyLifeApp
//
//  Created by Chanmin Park on 12/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let dataService: DataService
    let timerService: TimerService
    let syncService: WatchConnectivitySyncService?

    @State private var selectedTab = 0

    init(dataService: DataService, timerService: TimerService, syncService: WatchConnectivitySyncService? = nil) {
        self.dataService = dataService
        self.timerService = timerService
        self.syncService = syncService
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(dataService: dataService, timerService: timerService)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            GoalsView(dataService: dataService)
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(1)

            StatsView(dataService: dataService)
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(2)

            SettingsView(dataService: dataService, syncService: syncService)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        Activity.self,
        TimeEntry.self,
        ActiveTimer.self,
        Goal.self
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: config
    )

    let context = container.mainContext
    let dataService = DataService(modelContext: context)
    let timerService = TimerService(modelContext: context)

    ContentView(dataService: dataService, timerService: timerService)
        .modelContainer(container)
}
