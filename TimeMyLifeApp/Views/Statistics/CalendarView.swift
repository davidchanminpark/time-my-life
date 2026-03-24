//
//  CalendarView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct CalendarView: View {
    let dataService: DataService

    @State private var viewModel: CalendarViewModel
    @State private var showingDayDetail = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    init(dataService: DataService) {
        self.dataService = dataService
        _viewModel = State(wrappedValue: CalendarViewModel(dataService: dataService))
    }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    monthNavigation
                    weekdayHeader
                    calendarGrid
                    legend
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingDayDetail) {
            if let dayData = viewModel.selectedDayData {
                DayDetailView(dayData: dayData)
            }
        }
        .task { await viewModel.loadMonth() }
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button {
                viewModel.navigatePrevious()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            .foregroundStyle(Color.appAccent)
            .disabled(!viewModel.canGoBackward)
            .opacity(viewModel.canGoBackward ? 1 : 0.3)

            Spacer()

            Text(viewModel.monthTitle)
                .font(.system(.title3, design: .rounded, weight: .semibold))

            Spacer()

            Button {
                viewModel.navigateNext()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
            }
            .foregroundStyle(Color.appAccent)
            .disabled(!viewModel.canGoForward)
            .opacity(viewModel.canGoForward ? 1 : 0.3)
        }
    }

    // MARK: - Weekday Header

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdaySymbols.indices, id: \.self) { i in
                Text(weekdaySymbols[i])
                    .font(.system(.caption2, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(viewModel.gridDays.indices, id: \.self) { index in
                if let date = viewModel.gridDays[index] {
                    dayCell(date: date)
                } else {
                    Color.clear
                        .frame(height: 52)
                }
            }
        }
        .padding(8)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }

    private func dayCell(date: Date) -> some View {
        let dayData = viewModel.dayDataMap[date]
        let isToday = Calendar.current.isDateInToday(date)
        let isFuture = date > Calendar.current.startOfDay(for: Date())
        let dayNum = Calendar.current.component(.day, from: date)

        return VStack(spacing: 3) {
            Text("\(dayNum)")
                .font(.system(.subheadline, design: .rounded, weight: isToday ? .bold : .regular))
                .foregroundStyle(
                    isFuture ? Color.secondary.opacity(0.4)
                    : isToday ? Color.appAccent
                    : Color.primary
                )
                .frame(width: 30, height: 30)
                .background {
                    if isToday {
                        Circle().fill(Color.appAccent.opacity(0.12))
                    }
                }

            // Dots row (up to 3)
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { i in
                    if let colors = dayData?.dotColors, i < colors.count {
                        Circle()
                            .fill(colors[i])
                            .frame(width: 5, height: 5)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(height: 52)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isFuture, dayData != nil else { return }
            viewModel.selectedDate = date
            showingDayDetail = true
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            Label("Tracked", systemImage: "circle.fill")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Tap a day to see details")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

#Preview {
    let (container, dataService, _) = IOSViewPreviewSupport.dependencies()
    NavigationStack {
        CalendarView(dataService: dataService)
    }
    .modelContainer(container)
}

// MARK: - Day Detail Sheet

struct DayDetailView: View {
    let dayData: CalendarViewModel.DayData
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        if !dayData.items.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(dayData.items.indices, id: \.self) { i in
                                    let item = dayData.items[i]
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(item.color)
                                            .frame(width: 11, height: 11)
                                        Text(item.name)
                                            .font(.system(.subheadline, design: .rounded))
                                        Spacer()
                                        Text(formatDuration(item.duration))
                                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .monospacedDigit()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    if i < dayData.items.count - 1 {
                                        Divider().padding(.leading, 27)
                                    }
                                }
                            }
                            .appCard()
                        }

                        HStack {
                            Text("Total")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            Spacer()
                            Text(formatDuration(dayData.totalDuration))
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                        }
                        .padding(16)
                        .appCard()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(dayData.date.formatted(.dateTime.month().day().year()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
            }
        }
    }

    private func formatDuration(_ s: TimeInterval) -> String {
        let h = Int(s) / 3600, m = (Int(s) % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
