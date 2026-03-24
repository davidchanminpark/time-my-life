//
//  IOSViewPreviewSupport.swift
//  TimeMyLifeApp
//
//  In-memory SwiftData + sample rows for `#Preview` in iOS views.
//  If Xcode shows “cannot find in scope”, select this file → File Inspector →
//  ensure the **TimeMyLifeApp** target is checked.
//

import SwiftData
import SwiftUI

enum IOSViewPreviewSupport {
    static var schema: Schema {
        Schema([
            Activity.self,
            ScheduledDay.self,
            TimeEntry.self,
            ActiveTimer.self,
            Goal.self
        ])
    }

    /// In-memory store; optionally seeds `SampleData` activities + one daily goal.
    @MainActor
    static func makeContainer(seedSample: Bool = true) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        if seedSample {
            do {
                try seedPreviewData(in: container.mainContext)
            } catch {
                assertionFailure("Preview seed failed: \(error)")
            }
        }
        return container
    }

    @MainActor
    static func dependencies(seedSample: Bool = true) -> (ModelContainer, DataService, TimerService) {
        let container = makeContainer(seedSample: seedSample)
        let dataService = DataService(modelContext: container.mainContext)
        let timerService = TimerService(modelContext: container.mainContext)
        return (container, dataService, timerService)
    }

    @MainActor
    static func firstActivity(in context: ModelContext) -> Activity? {
        var descriptor = FetchDescriptor<Activity>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    private static func seedPreviewData(in context: ModelContext) throws {
        let activities = try SampleData.sampleActivities()
        for activity in activities {
            context.insert(activity)
        }
        if let first = activities.first {
            let goal = Goal(activityID: first.id, frequency: .daily, targetSeconds: 3600)
            context.insert(goal)
        }
        try context.save()
        _ = try ActiveTimer.shared(in: context)
    }
}

// MARK: - Full app chrome (floating tab bar) — iOS only

#if os(iOS)
/// SwiftUI canvas preview that matches the **real app shell**: iOS `ContentView`’s **floating pill tab bar** at the bottom.
///
/// Most `#Preview` blocks wrap only a single screen (`NavigationStack { HomeView(...) }`) so layout iteration is faster and
/// the canvas is less cluttered — those previews **intentionally omit** the bottom bar because it lives in `ContentView`.
/// Use this wrapper when you need to see tabs + the floating bar.
///
/// Wrapped in `#if os(iOS)` because this file is also compiled for the Watch target; watchOS `ContentView` has a different initializer (no `syncService`).
struct IOSPreviewFullAppShell: View {
    @State private var container: ModelContainer

    init(seedSample: Bool = true) {
        _container = State(initialValue: IOSViewPreviewSupport.makeContainer(seedSample: seedSample))
    }

    var body: some View {
        ContentView(
            dataService: DataService(modelContext: container.mainContext),
            timerService: TimerService(modelContext: container.mainContext),
            syncService: nil
        )
        .modelContainer(container)
    }
}
#endif
