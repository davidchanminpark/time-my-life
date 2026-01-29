//
//  GoalsView.swift
//  TimeMyLifeApp
//

import SwiftUI

struct GoalsView: View {
    let dataService: DataService

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Goals Coming Soon",
                systemImage: "target",
                description: Text("Track your daily and weekly activity goals")
            )
            .navigationTitle("Goals")
        }
    }
}
