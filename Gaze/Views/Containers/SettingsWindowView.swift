//
//  SettingsWindowView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct SettingsWindowView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var selectedSection: SettingsSection

    init(settingsManager: SettingsManager, initialTab: Int = 0) {
        self.settingsManager = settingsManager
        _selectedSection = State(initialValue: SettingsSection(rawValue: initialTab) ?? .general)
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.height < 600

            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    settingsContent

                    #if DEBUG
                    debugFooter(isCompact: isCompact)
                    #endif
                }
            }
            .environment(\.isCompactLayout, isCompact)
        }
        .frame(minWidth: AdaptiveLayout.Window.minWidth, minHeight: AdaptiveLayout.Window.minHeight)
        .onReceive(tabSwitchPublisher) { notification in
            if let tab = notification.object as? Int,
               let section = SettingsSection(rawValue: tab) {
                selectedSection = section
            }
        }
    }

    private var settingsContent: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            ScrollView {
                detailView(for: selectedSection)
            }
        }
    }

    private var sidebarContent: some View {
        List(SettingsSection.allCases, selection: $selectedSection) { section in
            NavigationLink(value: section) {
                Label(section.title, systemImage: section.iconName)
            }
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private func detailView(for section: SettingsSection) -> some View {
        switch section {
        case .general:
            GeneralSetupView(settingsManager: settingsManager, isOnboarding: false)
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

    private var tabSwitchPublisher: NotificationCenter.Publisher {
        NotificationCenter.default.publisher(
            for: SettingsWindowPresenter.switchTabNotification
        )
    }

    #if DEBUG
    @ViewBuilder
    private func debugFooter(isCompact: Bool) -> some View {
        Divider()
        HStack {
            Button("Retrigger Onboarding") {
                retriggerOnboarding()
            }
            .buttonStyle(.bordered)
            .controlSize(isCompact ? .small : .regular)
            Spacer()
        }
        .padding(isCompact ? 8 : 16)
    }

    private func retriggerOnboarding() {
        SettingsWindowPresenter.shared.close()
        settingsManager.settings.hasCompletedOnboarding = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            OnboardingWindowPresenter.shared.show(settingsManager: settingsManager)
        }
    }
    #endif
}

#Preview {
    SettingsWindowView(settingsManager: SettingsManager.shared)
}
