//
//  GeneralSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct GeneralSetupView: View {
    @Bindable var settingsManager: SettingsManager
    var isOnboarding: Bool = true

    #if !APPSTORE
    var updateManager = UpdateManager.shared
    #endif

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(
                icon: "gearshape.fill",
                title: isOnboarding ? "Final Settings" : "General Settings",
                color: .accentColor
            )

            Spacer()
            VStack(spacing: 30) {
                Text("Configure app preferences and support the project")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                settingsContent
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    @ViewBuilder
    private var settingsContent: some View {
        VStack(spacing: 20) {
            LaunchAtLoginSection(isEnabled: $settingsManager.settings.launchAtLogin)

            #if !APPSTORE
            SoftwareUpdatesSection(updateManager: updateManager)
            #endif

            ReminderSizeSection(selectedSize: $settingsManager.settings.subtleReminderSize)

            #if !APPSTORE
            SupportSection()
            #endif
        }
    }
}

#Preview("Settings Onboarding") {
    GeneralSetupView(settingsManager: SettingsManager.shared, isOnboarding: true)
}
