//
//  CompletionView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct CompletionView: View {
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

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.system(size: titleSize, weight: .bold))

            Text("Gaze will now help you take care of your eyes and posture")
                .font(isCompact ? .subheadline : .title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, isCompact ? 20 : 40)

            VStack(alignment: .leading, spacing: isCompact ? 10 : 16) {
                Text("What happens next:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)

                completionItem(icon: "menubar.rectangle", text: "Gaze will appear in your menu bar")
                completionItem(icon: "clock", text: "Timers will start automatically")
                completionItem(icon: "gearshape", text: "Adjust settings anytime from the menu bar")
                completionItem(icon: "plus.circle", text: "Create custom timers in Settings for additional reminders")
            }
            .padding(isCompact ? 12 : 16)
            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

            Spacer()
        }
        .frame(maxWidth: AdaptiveLayout.Content.maxWidth)
        .padding()
        .background(.clear)
    }
    
    @ViewBuilder
    private func completionItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal)
    }
}

#Preview("Completion View") {
    CompletionView()
}
