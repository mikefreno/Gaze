//
//  SettingsWindowView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    private var windowController: NSWindowController?
    private var closeObserver: NSObjectProtocol?

    func show(settingsManager: SettingsManager, initialTab: Int = 0) {
        if focusExistingWindow(tab: initialTab) { return }

        createWindow(settingsManager: settingsManager, initialTab: initialTab)
    }

    func close() {
        windowController?.close()
        windowController = nil
    }

    @discardableResult
    private func focusExistingWindow(tab: Int?) -> Bool {
        guard let window = windowController?.window else {
            windowController = nil
            return false
        }

        DispatchQueue.main.async {
            if let tab {
                NotificationCenter.default.post(
                    name: Notification.Name("SwitchToSettingsTab"),
                    object: tab
                )
            }

            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        return true
    }

    private func createWindow(settingsManager: SettingsManager, initialTab: Int) {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0,
                width: AdaptiveLayout.Window.defaultWidth,
                height: AdaptiveLayout.Window.defaultHeight
            ),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = WindowIdentifiers.settings
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.showsToolbarButton = false
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        window.collectionBehavior = [
            .managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary,
        ]

        window.contentView = NSHostingView(
            rootView: SettingsWindowView(settingsManager: settingsManager, initialTab: initialTab)
        )

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        windowController = controller

    }
}

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
                    NavigationSplitView {
                        List(SettingsSection.allCases, selection: $selectedSection) { section in
                            NavigationLink(value: section) {
                                Label(section.title, systemImage: section.iconName)
                            }
                        }
                        .listStyle(.sidebar)
                    } detail: {
                        ScrollView {
                            detailView(for: selectedSection)
                        }
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(
                            for: Notification.Name("SwitchToSettingsTab"))
                    ) { notification in
                        if let tab = notification.object as? Int,
                            let section = SettingsSection(rawValue: tab)
                        {
                            selectedSection = section
                        }
                    }

                    #if DEBUG
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
                    #endif
                }
            }
            .environment(\.isCompactLayout, isCompact)
        }
        .frame(minWidth: AdaptiveLayout.Window.minWidth, minHeight: AdaptiveLayout.Window.minHeight)
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

    #if DEBUG
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
