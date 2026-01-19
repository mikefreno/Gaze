//
//  WelcomeView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct WelcomeView: View {
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

            Image(systemName: "eye.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Gaze")
                .font(.system(size: titleSize, weight: .bold))

            Text("Take care of your eyes and posture")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: isCompact ? 12 : 16) {
                FeatureRow(
                    icon: "eye.trianglebadge.exclamationmark", title: "Reduce Eye Strain",
                    description: "Regular breaks help prevent digital eye strain")
                FeatureRow(
                    icon: "eye.circle", title: "Remember to Blink",
                    description: "We blink less when focused on screens")
                FeatureRow(
                    icon: "figure.stand", title: "Maintain Good Posture",
                    description: "Gentle reminders to sit up straight")
                FeatureRow(
                    icon: "plus.circle", title: "Custom Timers",
                    description: "Create your own timers for specific needs")
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

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    private var iconColor: Color {
        switch icon {
        case "eye.trianglebadge.exclamationmark": return .accentColor
        case "eye.circle": return .green
        case "figure.stand": return .orange
        default: return .primary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview("Welcome View") {
    WelcomeView()
}

#Preview("Feature Row") {
    FeatureRow(
        icon: "eye.circle",
        title: "Reduce Eye Strain",
        description: "Regular breaks help prevent digital eye strain"
    )
    .padding()
}
