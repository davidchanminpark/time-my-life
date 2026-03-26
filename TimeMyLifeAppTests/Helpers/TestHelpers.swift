//
//  TestHelpers.swift
//  TimeMyLifeAppTests
//

import SwiftData
@testable import TimeMyLifeApp

@MainActor
func makeTestDependencies() throws -> (ModelContainer, DataService) {
    let schema = Schema([Activity.self, TimeEntry.self, ActiveTimer.self, Goal.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: config)
    let dataService = DataService(modelContext: container.mainContext)
    return (container, dataService)
}
