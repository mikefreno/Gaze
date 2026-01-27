//
//  SupportSection.swift
//  Gaze
//
//  Support and contribute links section.
//

#if !APPSTORE
import SwiftUI

struct SupportSection: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Support & Contribute")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ExternalLinkButton(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "View on GitHub",
                subtitle: "Star the repo, report issues, contribute",
                url: "https://github.com/mikefreno/Gaze",
                tint: nil
            )

            ExternalLinkButton(
                icon: "cup.and.saucer.fill",
                iconColor: .brown,
                title: "Buy Me a Coffee",
                subtitle: "Support development of Gaze",
                url: "https://buymeacoffee.com/mikefreno",
                tint: .orange
            )
        }
        .padding()
    }
}

#Preview {
    SupportSection()
        .padding()
}
#endif
