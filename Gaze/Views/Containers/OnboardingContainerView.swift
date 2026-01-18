//
//  OnboardingContainerView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

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

    private var windowController: NSWindowController?
    private var closeObserver: NSObjectProtocol?

    func show(settingsManager: SettingsManager) {
        if activateIfPresent() {
            return
        }
        createWindow(settingsManager: settingsManager)
    }

    @discardableResult
    func activateIfPresent() -> Bool {
        guard let window = windowController?.window else {
            return false
        }

        // Even if not visible, we may still need to activate it if it exists
        let needsActivation = !window.isVisible || window.isMiniaturized

        if needsActivation {
            NSApp.unhide(nil)
            NSApp.activate(ignoringOtherApps: true)

            if window.isMiniaturized {
                window.deminiaturize(nil)
            }

            // Ensure the window is properly ordered front
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            // Make sure it's in the main space
            window.makeMain()

            return true
        }

        return false
    }

    func close() {
        // Notify overlay presenter to hide the guide overlay
        MenuBarGuideOverlayPresenter.shared.hide()
        
        windowController?.window?.close()
        windowController = nil
    }

    private func createWindow(settingsManager: SettingsManager) {
        let window = NSWindow(
            contentRect: NSRect(
                x: 0, y: 0, width: 1000,
                height: {
                    #if APPSTORE
                        return 700
                    #else
                        return 1000
                    #endif
                }()),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.identifier = WindowIdentifiers.onboarding
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
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
        
        // Setup observer for when the onboarding window closes
        MenuBarGuideOverlayPresenter.shared.setupOnboardingWindowObserver()
    }

}

struct OnboardingContainerView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var currentPage = 0

    private let lastPageIndex = 6

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomeView()
                        .tag(0)
                        .tabItem { Image(systemName: "hand.wave.fill") }

                    MenuBarWelcomeView()
                        .tag(1)
                        .tabItem { Image(systemName: "menubar.rectangle") }

                    LookAwaySetupView(settingsManager: settingsManager)
                        .tag(2)
                        .tabItem { Image(systemName: "eye.fill") }

                    BlinkSetupView(settingsManager: settingsManager)
                        .tag(3)
                        .tabItem { Image(systemName: "eye.circle.fill") }

                    PostureSetupView(settingsManager: settingsManager)
                        .tag(4)
                        .tabItem { Image(systemName: "figure.stand") }

                    GeneralSetupView(settingsManager: settingsManager, isOnboarding: true)
                        .tag(5)
                        .tabItem { Image(systemName: "gearshape.fill") }

                    CompletionView()
                        .tag(6)
                        .tabItem { Image(systemName: "checkmark.circle.fill") }
                }
                .tabViewStyle(.automatic)
                .onChange(of: currentPage) { _, newValue in
                    MenuBarGuideOverlayPresenter.shared.updateVisibility(isVisible: newValue == 1)
                }

                navigationButtons
            }
        }
        .frame(
            minWidth: 1000,
            minHeight: {
                #if APPSTORE
                    return 700
                #else
                    return 1000
                #endif
            }()
        )
        .onAppear {
            MenuBarGuideOverlayPresenter.shared.updateVisibility(isVisible: currentPage == 1)
        }
        .onDisappear {
            MenuBarGuideOverlayPresenter.shared.hide()
        }
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
                if currentPage == lastPageIndex {
                    completeOnboarding()
                } else {
                    currentPage += 1
                }
            }) {
                Text(
                    currentPage == 0
                        ? "Let's Get Started"
                        : currentPage == lastPageIndex ? "Get Started" : "Continue"
                )
                .font(.headline)
                .frame(minWidth: 100, maxWidth: .infinity, minHeight: 44, maxHeight: 44)
                .foregroundStyle(.white)
                .contentShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(
                GlassStyle.regular.tint(currentPage == lastPageIndex ? .green : .accentColor)
                    .interactive(),
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
