//
//  ContentView.swift
//  TimeMyLifeWatch Watch App
//
//  Created by Chanmin Park on 12/9/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let dataService: DataService
    let timerService: TimerService

    var body: some View {
        MainView(dataService: dataService, timerService: timerService)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let schema = Schema([
        Activity.self,
        TimeEntry.self,
        ActiveTimer.self
    ])
    let container = try! ModelContainer(
        for: schema,
        configurations: config
    )

    let context = container.mainContext
    let dataService = DataService(modelContext: context)
    let timerService = TimerService(modelContext: context)

    return ContentView(dataService: dataService, timerService: timerService)
        .modelContainer(container)
}
