//
//  AppTheme.swift
//  TimeMyLifeApp
//

import SwiftUI
import UIKit

// MARK: - Appearance Preference

/// User-selectable appearance override. `.system` defers to iOS settings;
/// `.light` / `.dark` force the app into that mode regardless of system.
enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Maps to SwiftUI's `preferredColorScheme`. `nil` means follow system.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Theme Colors

extension Color {
    /// Warm cream in light mode, dark background in dark mode
    static let appBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
            : UIColor(red: 0.980, green: 0.973, blue: 0.961, alpha: 1)
    })
    /// Lavender-purple for active states, primary buttons #8B7FE8
    static let appAccent = Color(red: 0.545, green: 0.498, blue: 0.910)
    /// Soft lavender for selected tab chip #D4BAFF
    static let appTabSelected = Color(red: 0.831, green: 0.729, blue: 1.000)
    /// Adaptive card surface: white in light, light grey in dark mode
    static let appCardBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1)
            : UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1)
    })
}

// MARK: - Reusable Modifiers

extension View {
    /// Card: 18pt radius + soft drop shadow, adapts to dark mode
    func appCard() -> some View {
        self
            .background(Color.appCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 3)
    }
}
