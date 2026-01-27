//
//  ExternalLinkButton.swift
//  Gaze
//
//  Reusable external link button component.
//

import SwiftUI

struct ExternalLinkButton: View {
    let icon: String
    var iconColor: Color = .primary
    let title: String
    let subtitle: String
    let url: String
    let tint: Color?

    var body: some View {
        Button(action: openURL) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(
            tint != nil ? GlassStyle.regular.tint(tint!).interactive() : GlassStyle.regular.interactive(),
            in: .rect(cornerRadius: 10)
        )
    }

    private func openURL() {
        if let url = URL(string: url) {
            NSWorkspace.shared.open(url)
        }
    }
}

#Preview {
    VStack {
        ExternalLinkButton(
            icon: "star.fill",
            iconColor: .yellow,
            title: "Example Link",
            subtitle: "A subtitle describing the link",
            url: "https://example.com",
            tint: .blue
        )

        ExternalLinkButton(
            icon: "link",
            title: "Plain Link",
            subtitle: "Without tint",
            url: "https://example.com",
            tint: nil
        )
    }
    .padding()
}
