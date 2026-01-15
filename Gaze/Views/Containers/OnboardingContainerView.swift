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

    func show(settingsManager: SettingsManager) {
        if activateIfPresent() {
            return
        }
        createWindow(settingsManager: settingsManager)
    }

    @discardableResult
    func activateIfPresent() -> Bool {
        guard let window = windowController?.window else {
            windowController = nil
            return false
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func close() {
        windowController?.close()
        windowController = nil
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
            self.closeObserver = nil
        }
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
        window.contentView = NSHostingView(
            rootView: OnboardingContainerView(settingsManager: settingsManager)
        )

        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windowController = controller

        closeObserver.map(NotificationCenter.default.removeObserver)
        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.windowController = nil
            if let closeObserver = self?.closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }
            self?.closeObserver = nil
        }
    }

    deinit {
        if let closeObserver {
            NotificationCenter.default.removeObserver(closeObserver)
        }
    }
}

struct OnboardingContainerView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var currentPage = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomeView()
                        .tag(0)
                        .tabItem {
                            Image(systemName: "hand.wave.fill")
                        }

                    LookAwaySetupView(settingsManager: settingsManager)
                        .tag(1)
                        .tabItem {
                            Image(systemName: "eye.fill")
                        }

                    BlinkSetupView(settingsManager: settingsManager)
                        .tag(2)
                        .tabItem {
                            Image(systemName: "eye.circle.fill")
                        }

                    PostureSetupView(settingsManager: settingsManager)
                        .tag(3)
                        .tabItem {
                            Image(systemName: "figure.stand")
                        }

                    GeneralSetupView(
                        settingsManager: settingsManager,
                        isOnboarding: true
                    )
                    .tag(4)
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                    }

                    CompletionView()
                        .tag(5)
                        .tabItem {
                            Image(systemName: "checkmark.circle.fill")
                        }
                }
                .tabViewStyle(.automatic)

                if currentPage >= 0 {
                    HStack(spacing: 12) {
                        if currentPage > 0 {
                            Button(action: { currentPage -= 1 }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .font(.headline)
                                .frame(
                                    minWidth: 100, maxWidth: .infinity, minHeight: 44,
                                    maxHeight: 44, alignment: .center
                                )
                                .foregroundColor(.primary)
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
                                    ? "Let's Get Started"
                                    : currentPage == 5 ? "Get Started" : "Continue"
                            )
                            .font(.headline)
                            .frame(
                                minWidth: 100, maxWidth: .infinity, minHeight: 44, maxHeight: 44,
                                alignment: .center
                            )
                            .foregroundColor(.white)
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .glassEffectIfAvailable(
                            GlassStyle.regular.tint(currentPage == 5 ? .green : .accentColor)
                                .interactive(),
                            in: .rect(cornerRadius: 10))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                }
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
    }

    private func completeOnboarding() {
        // Mark onboarding as complete - settings are already being updated in real-time
        settingsManager.settings.hasCompletedOnboarding = true

        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            if let menuBarWindow = NSApp.windows.first(where: {
                $0.className.contains("MenuBarExtra") || $0.className.contains("StatusBar")
            }),
                let statusItem = menuBarWindow.value(forKey: "statusItem") as? NSStatusItem
            {
                statusItem.button?.performClick(nil)
            }
        }
    }
}
#Preview("Onboarding Container") {
    OnboardingContainerView(settingsManager: SettingsManager.shared)
}
