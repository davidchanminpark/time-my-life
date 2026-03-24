//
//  CircularProgressView.swift
//  TimeMyLifeApp
//

import SwiftUI

struct CircularProgressView: View {
    let progress: Double    // 0.0 to 1.0+ (capped at 1.0 for ring fill)
    let color: Color
    var size: CGFloat = 60
    var lineWidth: CGFloat = 6

    private var displayProgress: Double {
        min(progress, 1.0)
    }

    private var percentText: String {
        let pct = Int(min(progress * 100, 999))
        return "\(pct)%"
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)

            // Progress arc (clockwise from top)
            Circle()
                .trim(from: 0, to: displayProgress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.4), value: displayProgress)

            // Percent label
            Text(percentText)
                .font(.system(size: size * 0.21, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 20) {
        CircularProgressView(progress: 0.0, color: .blue)
        CircularProgressView(progress: 0.6, color: .green)
        CircularProgressView(progress: 1.0, color: .orange)
        CircularProgressView(progress: 1.2, color: .purple)
    }
    .padding()
}
