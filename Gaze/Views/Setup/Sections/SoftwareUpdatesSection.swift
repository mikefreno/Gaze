//
//  SoftwareUpdatesSection.swift
//  Gaze
//
//  Software updates settings section.
//

#if !APPSTORE
import SwiftUI

struct SoftwareUpdatesSection: View {
    @ObservedObject var updateManager: UpdateManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Software Updates")
                    .font(.headline)

                lastCheckText
            }

            Spacer()

            Button("Check for Updates Now") {
                updateManager.checkForUpdates()
            }
            .buttonStyle(.bordered)

            Toggle(
                "Automatically check for updates",
                isOn: Binding(
                    get: { updateManager.automaticallyChecksForUpdates },
                    set: { updateManager.automaticallyChecksForUpdates = $0 }
                )
            )
            .labelsHidden()
            .help("Check for new versions of Gaze in the background")
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    @ViewBuilder
    private var lastCheckText: some View {
        if let lastCheck = updateManager.lastUpdateCheckDate {
            Text("Last checked: \(lastCheck, style: .relative)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        } else {
            Text("Never checked for updates")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
    }
}

#Preview {
    SoftwareUpdatesSection(updateManager: UpdateManager.shared)
        .padding()
}
#endif
