//
//  SettingsWindowView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct SettingsWindowView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var selectedSection: SettingsSection

    init(settingsManager: SettingsManager, initialTab: Int = 0) {
        self.settingsManager = settingsManager
        _selectedSection = State(initialValue: SettingsSection(rawValue: initialTab) ?? .general)
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                NavigationSplitView {
                    List(SettingsSection.allCases, selection: $selectedSection) { section in
                        NavigationLink(value: section) {
                            Label(section.title, systemImage: section.iconName)
                        }
                    }
                    .listStyle(.sidebar)
                } detail: {
                    detailView(for: selectedSection)
                }

                #if DEBUG
                    Divider()

                    HStack {
                        Button("Retrigger Onboarding") {
                            retriggerOnboarding()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding()
                #endif
            }
        }
        #if APPSTORE
            .frame(
                minWidth: 1000,
                minHeight: 700
            )
        #else
            .frame(
                minWidth: 1000,
                minHeight: 900
            )
        #endif
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("SwitchToSettingsTab"))
        ) { notification in
            if let tab = notification.object as? Int,
                let section = SettingsSection(rawValue: tab)
            {
                selectedSection = section
            }
        }
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSetupView(
                settingsManager: settingsManager,
                isOnboarding: false
            )
        case .lookAway:
            LookAwaySetupView(settingsManager: settingsManager)
        case .blink:
            BlinkSetupView(settingsManager: settingsManager)
        case .posture:
            PostureSetupView(settingsManager: settingsManager)
        case .enforceMode:
            EnforceModeSetupView(settingsManager: settingsManager)
        case .userTimers:
            UserTimersView(
                userTimers: Binding(
                    get: { settingsManager.settings.userTimers },
                    set: { settingsManager.settings.userTimers = $0 }
                )
            )
        case .smartMode:
            SmartModeSetupView(settingsManager: settingsManager)
        }
    }

    #if DEBUG
        private func retriggerOnboarding() {
            OnboardingWindowPresenter.shared.close()
            SettingsWindowPresenter.shared.close()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.settingsManager.settings.hasCompletedOnboarding = false

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    OnboardingWindowPresenter.shared.show(settingsManager: self.settingsManager)
                }
            }
        }
    #endif
}

#Preview {
    SettingsWindowView(settingsManager: SettingsManager.shared)
}
