//
//  ActivityAvatarView.swift
//  TimeMyLifeApp
//

import SwiftUI

struct ActivityAvatarView: View {
    let activity: Activity
    var size: CGFloat = 48
    var shadow: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27)
                .fill(
                    activity.emoji.isEmpty
                        ? activity.color()
                        : activity.color().opacity(0.18)
                )
                .frame(width: size, height: size)
                .shadow(
                    color: shadow ? activity.color().opacity(0.45) : .clear,
                    radius: shadow ? size * 0.24 : 0,
                    x: 0,
                    y: shadow ? size * 0.1 : 0
                )
            if activity.emoji.isEmpty {
                Text(String(activity.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(white: 0.18))
            } else {
                Text(activity.emoji)
                    .font(.system(size: size * 0.54))
            }
        }
    }
}
