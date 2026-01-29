//
//  StatsView.swift
//  TimeMyLifeApp
//

import SwiftUI

struct StatsView: View {
    let dataService: DataService

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Statistics Coming Soon",
                systemImage: "chart.bar.fill",
                description: Text("View detailed activity statistics and trends")
            )
            .navigationTitle("Statistics")
        }
    }
}
