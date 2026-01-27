//
//  LaunchAtLoginSection.swift
//  Gaze
//
//  Launch at login toggle section.
//

import SwiftUI

struct LaunchAtLoginSection: View {
    @Binding var isEnabled: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Launch at Login")
                    .font(.headline)
                Text("Start Gaze automatically when you log in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, newValue in
                    applyLaunchAtLoginSetting(enabled: newValue)
                }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    private func applyLaunchAtLoginSetting(enabled: Bool) {
        do {
            if enabled {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
        } catch {
            logError("⚠️ Failed to set launch at login: \(error)")
        }
    }
}

#Preview {
    LaunchAtLoginSection(isEnabled: .constant(true))
        .padding()
}
