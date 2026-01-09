//
//  WelcomeView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "eye.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            Text("Welcome to Gaze")
                .font(.system(size: 36, weight: .bold))

            Text("Take care of your eyes and posture")
                .font(.title3)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
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
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))

            Spacer()
        }
        .frame(width: 600, height: 450)
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
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
