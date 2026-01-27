//
//  MenuBarTargetView.swift
//  Gaze
//
//  Created by Mike Freno on 1/17/26.
//

import SwiftUI

struct MenuBarTargetView: View {
    @Environment(\.isCompactLayout) private var isCompact

    private var iconSize: CGFloat {
        isCompact ? AdaptiveLayout.Font.heroIconSmall : AdaptiveLayout.Font.heroIcon
    }

    private var titleSize: CGFloat {
        isCompact ? AdaptiveLayout.Font.heroTitleSmall : AdaptiveLayout.Font.heroTitle
    }

    private var spacing: CGFloat {
        isCompact ? AdaptiveLayout.Spacing.compact : AdaptiveLayout.Spacing.standard
    }

    var body: some View {
        VStack(spacing: spacing * 1.5) {
            Spacer()

            Image(systemName: "menubar.rectangle")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Gaze Lives in Your Menu Bar")
                    .font(.system(size: titleSize, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Keep an eye on the top-right of your screen for the Gaze icon.")
                    .font(isCompact ? .subheadline : .title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
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
            .padding(isCompact ? 12 : 16)
            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

            Spacer()
        }
        .frame(maxWidth: AdaptiveLayout.Content.maxWidth)
        .padding()
        .background(.clear)
    }
}

#Preview("Menu Bar Welcome") {
    MenuBarTargetView()
}
