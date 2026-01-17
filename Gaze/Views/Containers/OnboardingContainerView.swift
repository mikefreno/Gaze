//
//  OnboardingContainerView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

@MainActor
final class OnboardingWindowPresenter {
    static let shared = OnboardingWindowPresenter()

    private weak var windowController: NSWindowController?
    private var closeObserver: NSObjectProtocol?
    private var isShowingWindow = false

    func show(settingsManager: SettingsManager) {
        if activateIfPresent() { return }
        guard !isShowingWindow else { return }
        isShowingWindow = true
        createWindow(settingsManager: settingsManager)
    }

    @discardableResult
    func activateIfPresent() -> Bool {
        guard let window = windowController?.window else {
            windowController = nil
            return false
        }

        DispatchQueue.main.async {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            window.makeMain()
        }
        return true
    }

    func close() {
        windowController?.close()
        windowController = nil
        isShowingWindow = false
        removeCloseObserver()
    }

    private func createWindow(settingsManager: SettingsManager) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = WindowIdentifiers.onboarding
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = true
        window.collectionBehavior = [
            .managed, .participatesInCycle, .moveToActiveSpace, .fullScreenAuxiliary,
        ]

        window.contentView = NSHostingView(
            rootView: OnboardingContainerView(settingsManager: settingsManager)
        )

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        windowController = controller

        removeCloseObserver()
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.windowController = nil
                self?.isShowingWindow = false
                self?.removeCloseObserver()
            }
            NotificationCenter.default.post(
                name: Notification.Name("OnboardingWindowDidClose"), object: nil)
        }
    }

    private func removeCloseObserver() {
        if let observer = closeObserver {
            NotificationCenter.default.removeObserver(observer)
            closeObserver = nil
        }
    }
}

struct OnboardingContainerView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var currentPage = 0

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomeView()
                        .tag(0)
                        .tabItem { Image(systemName: "hand.wave.fill") }

                    LookAwaySetupView(settingsManager: settingsManager)
                        .tag(1)
                        .tabItem { Image(systemName: "eye.fill") }

                    BlinkSetupView(settingsManager: settingsManager)
                        .tag(2)
                        .tabItem { Image(systemName: "eye.circle.fill") }

                    PostureSetupView(settingsManager: settingsManager)
                        .tag(3)
                        .tabItem { Image(systemName: "figure.stand") }

                    GeneralSetupView(settingsManager: settingsManager, isOnboarding: true)
                        .tag(4)
                        .tabItem { Image(systemName: "gearshape.fill") }

                    CompletionView()
                        .tag(5)
                        .tabItem { Image(systemName: "checkmark.circle.fill") }
                }
                .tabViewStyle(.automatic)

                navigationButtons
            }
        }
        #if APPSTORE
            .frame(minWidth: 1000, minHeight: 700)
        #else
            .frame(minWidth: 1000, minHeight: 900)
        #endif
    }

    @ViewBuilder
    private var navigationButtons: some View {
        HStack(spacing: 12) {
            if currentPage > 0 {
                Button(action: { currentPage -= 1 }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.headline)
                    .frame(minWidth: 100, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                    .foregroundStyle(.primary)
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .glassEffectIfAvailable(
                    GlassStyle.regular.interactive(), in: .rect(cornerRadius: 10))
            }

            Button(action: {
                if currentPage == 5 {
                    completeOnboarding()
                } else {
                    currentPage += 1
                }
            }) {
                Text(
                    currentPage == 0
                        ? "Let's Get Started" : currentPage == 5 ? "Get Started" : "Continue"
                )
                .font(.headline)
                .frame(minWidth: 100, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .foregroundStyle(.white)
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(
                GlassStyle.regular.tint(currentPage == 5 ? .green : .accentColor).interactive(),
                in: .rect(cornerRadius: 10)
            )
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 20)
    }

    private func completeOnboarding() {
        settingsManager.settings.hasCompletedOnboarding = true
        OnboardingWindowPresenter.shared.close()
    }
}

#Preview("Onboarding Container") {
    OnboardingContainerView(settingsManager: SettingsManager.shared)
}
