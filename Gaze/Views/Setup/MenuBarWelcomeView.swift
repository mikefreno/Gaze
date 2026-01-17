//
//  MenuBarWelcomeView.swift
//  Gaze
//
//  Created by Mike Freno on 1/17/26.
//

import SwiftUI

struct MenuBarWelcomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "menubar.rectangle")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Gaze Lives in Your Menu Bar")
                    .font(.system(size: 34, weight: .bold))

                Text("Keep an eye on the top-right of your screen for the Gaze icon.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "cursorarrow.click", title: "Always Within Reach",
                    description: "Open settings and timers from the menu bar anytime")
                FeatureRow(
                    icon: "bell.badge", title: "Friendly Reminders",
                    description: "Notifications pop up without interrupting your flow")
                FeatureRow(
                    icon: "sparkles", title: "Quick Tweaks",
                    description: "Pause, resume, and adjust timers in one click")
            }
            .padding()
            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

            Spacer()
        }
        .frame(width: 600, height: 450)
        .padding()
        .background(.clear)
    }
}

#Preview("Menu Bar Welcome") {
    MenuBarWelcomeView()
}
