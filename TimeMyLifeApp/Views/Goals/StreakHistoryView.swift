//
//  StreakHistoryView.swift
//  TimeMyLifeApp
//

import SwiftUI

/// Displays the last N periods as small colored squares (✓ = met, ✗ = not met)
struct StreakHistoryView: View {
    let history: [Bool]     // oldest → newest
    let color: Color
    var squareSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) {
            ForEach(history.indices, id: \.self) { index in
                periodSquare(met: history[index])
            }
        }
    }

    private func periodSquare(met: Bool) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(met ? color.opacity(0.85) : Color(.systemGray5))
            .frame(width: squareSize, height: squareSize)
            .overlay {
                Image(systemName: met ? "checkmark" : "xmark")
                    .font(.system(size: squareSize * 0.45, weight: .bold))
                    .foregroundStyle(met ? .white : Color(.systemGray3))
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        StreakHistoryView(history: [true, true, false, true, true, true], color: .blue)
        StreakHistoryView(history: [false, false, false, false, false, false], color: .red)
        StreakHistoryView(history: [true, true, true, true, true, true], color: .green)
    }
    .padding()
}
