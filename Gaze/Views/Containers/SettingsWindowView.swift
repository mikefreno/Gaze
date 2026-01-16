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

    private weak var windowController: NSWindowController?
    private var closeObserver: NSObjectProtocol?

    func show(settingsManager: SettingsManager, initialTab: Int = 0) {
        if focusExistingWindow(tab: initialTab) { return }
        createWindow(settingsManager: settingsManager, initialTab: initialTab)
    }

    func focus(tab: Int) {
        _ = focusExistingWindow(tab: tab)
    }

    func close() {
        windowController?.close()
        windowController = nil
        removeCloseObserver()
    }

    @discardableResult
    private func focusExistingWindow(tab: Int?) -> Bool {
        guard let window = windowController?.window else {
            windowController = nil
            return false
        }

        if let tab {
            NotificationCenter.default.post(
                name: Notification.Name("SwitchToSettingsTab"),
                object: tab
            )
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private func createWindow(settingsManager: SettingsManager, initialTab: Int) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
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

        window.contentView = NSHostingView(
            rootView: SettingsWindowView(settingsManager: settingsManager, initialTab: initialTab)
        )

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windowController = controller

        removeCloseObserver()
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.windowController = nil
                self?.removeCloseObserver()
                NotificationCenter.default.post(name: Notification.Name("SettingsWindowDidClose"), object: nil)
            }
        }
    }

    private func removeCloseObserver() {
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }
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
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SwitchToSettingsTab"))) { notification in
                    if let tab = notification.object as? Int,
                       let section = SettingsSection(rawValue: tab) {
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
                    Spacer()
                }
                .padding()
                #endif
            }
        }
        #if APPSTORE
        .frame(minWidth: 1000, minHeight: 700)
        #else
        .frame(minWidth: 1000, minHeight: 900)
        #endif
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            settingsManager.settings.hasCompletedOnboarding = false
        }
    }
    #endif
}

#Preview {
    SettingsWindowView(settingsManager: SettingsManager.shared)
}
