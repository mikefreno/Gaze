//
//  SettingsWindowPresenter.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()

    static let switchTabNotification = Notification.Name("SwitchToSettingsTab")

    private var windowController: NSWindowController?

    private init() {}

    func show(settingsManager: SettingsManager, initialTab: Int = 0) {
        if focusExistingWindow(tab: initialTab) { return }
        createWindow(settingsManager: settingsManager, initialTab: initialTab)
    }

    func show(settingsManager: SettingsManager, section: SettingsSection) {
        show(settingsManager: settingsManager, initialTab: section.rawValue)
    }

    func close() {
        windowController?.close()
        windowController = nil
    }

    var isVisible: Bool {
        windowController?.window?.isVisible ?? false
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
                    name: Self.switchTabNotification,
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
        let window = makeWindow()

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

    private func makeWindow() -> NSWindow {
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

        return window
    }
}
