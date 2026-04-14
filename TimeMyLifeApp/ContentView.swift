//
//  ContentView.swift
//  TimeMyLifeApp
//

import SwiftUI
import SwiftData

struct ContentView: View {
    let dataService: DataService
    let timerService: TimerService
    let notificationService: NotificationService
    let syncService: WatchConnectivitySyncService?

    @State private var selectedTab = 0

    init(dataService: DataService, timerService: TimerService, notificationService: NotificationService, syncService: WatchConnectivitySyncService? = nil) {
        self.dataService = dataService
        self.timerService = timerService
        self.notificationService = notificationService
        self.syncService = syncService
        // Hide the system tab bar globally so our custom one takes over
        UITabBar.appearance().isHidden = true

        // Use SF Pro Rounded for all navigation bar titles
        let roundedInline = UIFont.systemFont(ofSize: 20, weight: .semibold)
            .rounded()
        let roundedLarge = UIFont.systemFont(ofSize: 34, weight: .bold)
            .rounded()
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.font: roundedInline]
        appearance.largeTitleTextAttributes = [.font: roundedLarge]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(dataService: dataService, timerService: timerService)
                    .tag(0)

                GoalsView(dataService: dataService)
                    .tag(1)

                StatsView(dataService: dataService)
                    .tag(2)

                SettingsView(dataService: dataService, notificationService: notificationService, syncService: syncService)
                    .tag(3)
            }
            // Reserve space at the bottom so list content scrolls above the floating bar
            .safeAreaInset(edge: .bottom) {
                Color.clear.frame(height: 90)
            }

            FloatingTabBar(selectedTab: $selectedTab)
        }
        .foregroundStyle(Color.appPrimaryText)
        .fontDesign(.rounded)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Floating Pill Tab Bar

private struct FloatingTabBar: View {
    @Binding var selectedTab: Int

    private let items: [(icon: String, tag: Int)] = [
        ("house.fill", 0),
        ("target", 1),
        ("chart.bar.fill", 2),
        ("gearshape.fill", 3)
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tag) { item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                        selectedTab = item.tag
                    }
                } label: {
                    Image(systemName: item.icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(
                            selectedTab == item.tag
                                ? Color.appAccent
                                : Color.secondary.opacity(0.45)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            if selectedTab == item.tag {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.appTabSelected.opacity(0.35))
                                    .padding(.horizontal, 6)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.appCardBackground)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.10), radius: 22, x: 0, y: 5)
        .padding(.horizontal, 32)
        .padding(.bottom, 20)
    }
}

#Preview("Full app — floating tab bar") {
    IOSPreviewFullAppShell()
}

#Preview("Full app — floating tab bar (empty store)") {
    IOSPreviewFullAppShell(seedSample: false)
}
