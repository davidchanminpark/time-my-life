//
//  AppTheme.swift
//  TimeMyLifeApp
//

import SwiftUI

// MARK: - Theme Colors

extension Color {
    /// Warm cream page background #FAF8F5
    static let appBackground = Color(red: 0.980, green: 0.973, blue: 0.961)
    /// Lavender-purple for active states, primary buttons #8B7FE8
    static let appAccent = Color(red: 0.545, green: 0.498, blue: 0.910)
    /// Soft lavender for selected tab chip #D4BAFF
    static let appTabSelected = Color(red: 0.831, green: 0.729, blue: 1.000)
}

// MARK: - Reusable Modifiers

extension View {
    /// White card: 18pt radius + soft drop shadow
    func appCard() -> some View {
        self
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}
