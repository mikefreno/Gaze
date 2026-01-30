//
//  SmartModeSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import SwiftUI

struct SmartModeSetupView: View {
    @Bindable var settingsManager: SettingsManager

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "brain.fill", title: "Smart Mode", color: .purple)

            SmartModeSetupContent(
                settingsManager: settingsManager,
                presentation: .window
            )
            .padding(.top, 24)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }
}

#Preview {
    SmartModeSetupView(settingsManager: SettingsManager.shared)
}
