//
//  CalendarViewModel.swift
//  TimeMyLifeApp
//

import Foundation
import SwiftUI
import Observation

@Observable
@MainActor
class CalendarViewModel {

    // MARK: - Types

    struct DayData: Identifiable {
        var id: Date { date }
        let date: Date
        /// Activities tracked on this day, sorted by duration descending
        let items: [(name: String, color: Color, duration: TimeInterval)]

        var isTracked: Bool { !items.isEmpty }
        var dotColors: [Color] { items.prefix(3).map { $0.color } }
        var totalDuration: TimeInterval { items.reduce(0) { $0 + $1.duration } }
    }

    // MARK: - State

    var displayedMonth: Date    // first day of the currently shown month
    /// Start of earliest month allowed (from `DataService.earliestCalendarDisplayMonthStart`).
    var earliestNavigableMonth: Date
    var dayDataMap: [Date: DayData] = [:]
    var selectedDate: Date? = nil
    var isLoading = false

    var selectedDayData: DayData? {
        guard let date = selectedDate else { return nil }
        return dayDataMap[date]
    }

    // MARK: - Calendar Grid

    private let cal = Calendar.current

    /// Dates (or nil for empty cells) to fill the 7-column grid
    var gridDays: [Date?] {
        guard let monthInterval = cal.dateInterval(of: .month, for: displayedMonth) else { return [] }
        let firstDay = monthInterval.start
        let daysInMonth = cal.range(of: .day, in: .month, for: displayedMonth)?.count ?? 30

        // Leading empty cells so that firstDay falls on the correct weekday column
        let firstWeekday = cal.component(.weekday, from: firstDay) - 1  // 0 = Sun
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)

        for d in 0..<daysInMonth {
            days.append(cal.date(byAdding: .day, value: d, to: firstDay))
        }

        // Trailing padding to complete the last row
        let remainder = days.count % 7
        if remainder != 0 { days += Array(repeating: nil, count: 7 - remainder) }
        return days
    }

    var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month(.wide))
    }

    private var latestNavigableMonth: Date {
        cal.date(from: cal.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    var canGoForward: Bool {
        cal.compare(displayedMonth, to: latestNavigableMonth, toGranularity: .month) == .orderedAscending
    }

    var canGoBackward: Bool {
        cal.compare(displayedMonth, to: earliestNavigableMonth, toGranularity: .month) == .orderedDescending
    }

    // MARK: - Init

    private let dataService: DataService

    init(dataService: DataService) {
        self.dataService = dataService
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let startOfThisMonth = Calendar.current.date(from: components) ?? Date()
        self.displayedMonth = startOfThisMonth
        self.earliestNavigableMonth = (try? dataService.earliestCalendarDisplayMonthStart()) ?? startOfThisMonth
    }

    // MARK: - Load

    func loadMonth() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let earliest = try dataService.earliestCalendarDisplayMonthStart()
            earliestNavigableMonth = earliest
            let latest = latestNavigableMonth
            if cal.compare(displayedMonth, to: earliest, toGranularity: .month) == .orderedAscending {
                displayedMonth = earliest
            }
            if cal.compare(displayedMonth, to: latest, toGranularity: .month) == .orderedDescending {
                displayedMonth = latest
            }
        } catch {
            print("CalendarViewModel bounds error: \(error)")
        }

        guard let interval = cal.dateInterval(of: .month, for: displayedMonth) else { return }
        let start = interval.start
        // end = last day of month
        let end = cal.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end

        do {
            let activities = try dataService.fetchActivities()
            let activityMap = Dictionary(uniqueKeysWithValues: activities.map { ($0.id, $0) })
            let entries = try dataService.fetchTimeEntries(from: start, to: end)

            var grouped: [Date: [(name: String, color: Color, duration: TimeInterval)]] = [:]
            for entry in entries where entry.totalDuration > 0 {
                guard let act = activityMap[entry.activityID] else { continue }
                grouped[entry.date, default: []].append((act.name, act.color(), entry.totalDuration))
            }

            dayDataMap = [:]
            for (date, rawItems) in grouped {
                let sorted = rawItems.sorted { $0.duration > $1.duration }
                dayDataMap[date] = DayData(date: date, items: sorted)
            }

        } catch {
            print("CalendarViewModel error: \(error)")
        }
    }

    // MARK: - Navigation

    func navigatePrevious() {
        guard canGoBackward,
              let prev = cal.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = prev
        Task { await loadMonth() }
    }

    func navigateNext() {
        guard canGoForward,
              let next = cal.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = next
        Task { await loadMonth() }
    }
}
