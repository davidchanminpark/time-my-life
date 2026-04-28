//
//  WatchAppTheme.swift
//  TimeMyLife Watch App
//
//  Shared accent colors and typography matching the iOS app theme.
//  Background stays black per watchOS HIG; only accents and fonts are aligned.
//

import SwiftUI

// MARK: - Theme Colors

extension Color {
    /// Lavender-purple accent — matches iOS `Color.appAccent` #8B7FE8
    static let watchAccent = Color(red: 0.545, green: 0.498, blue: 0.910)
    /// Coral for stop/destructive actions — matches iOS timer stop color
    static let watchStop = Color(red: 0.91, green: 0.42, blue: 0.42)
}
