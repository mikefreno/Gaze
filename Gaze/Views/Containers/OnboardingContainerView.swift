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

struct OnboardingContainerView: View {
    @ObservedObject var settingsManager: SettingsManager
    @State private var currentPage = 0
    @State private var lookAwayEnabled = true
    @State private var lookAwayIntervalMinutes = 20
    @State private var lookAwayCountdownSeconds = 20
    @State private var blinkEnabled = false
    @State private var blinkIntervalMinutes = 5
    @State private var postureEnabled = true
    @State private var postureIntervalMinutes = 30
    @State private var launchAtLogin = false
    @State private var subtleReminderSize: ReminderSize = .medium
    @State private var isAppStoreVersion: Bool
    @Environment(\.dismiss) private var dismiss

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        _isAppStoreVersion = State(initialValue: settingsManager.settings.isAppStoreVersion)
    }

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

                    LookAwaySetupView(
                        enabled: $lookAwayEnabled,
                        intervalMinutes: $lookAwayIntervalMinutes,
                        countdownSeconds: $lookAwayCountdownSeconds
                    )
                    .tag(1)
                    .tabItem {
                        Image(systemName: "eye.fill")
                    }

                    BlinkSetupView(
                        enabled: $blinkEnabled,
                        intervalMinutes: $blinkIntervalMinutes,
                        subtleReminderSize: subtleReminderSize
                    )
                    .tag(2)
                    .tabItem {
                        Image(systemName: "eye.circle.fill")
                    }

                    PostureSetupView(
                        enabled: $postureEnabled,
                        intervalMinutes: $postureIntervalMinutes,
                        subtleReminderSize: subtleReminderSize
                    )
                    .tag(3)
                    .tabItem {
                        Image(systemName: "figure.stand")
                    }

                    GeneralSetupView(
                        launchAtLogin: $launchAtLogin,
                        subtleReminderSize: $subtleReminderSize,
                        isAppStoreVersion: .constant(isAppStoreVersion),
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

        .frame(
            minWidth: 1000,
            minHeight: isAppStoreVersion ? 700 : 900
        )
        .onReceive(settingsManager.$settings) { newSettings in
            isAppStoreVersion = newSettings.isAppStoreVersion
        }
    }

    private func completeOnboarding() {
        // Save settings
        settingsManager.settings.lookAwayTimer = TimerConfiguration(
            enabled: lookAwayEnabled,
            intervalSeconds: lookAwayIntervalMinutes * 60
        )
        settingsManager.settings.lookAwayCountdownSeconds = lookAwayCountdownSeconds

        settingsManager.settings.blinkTimer = TimerConfiguration(
            enabled: blinkEnabled,
            intervalSeconds: blinkIntervalMinutes * 60
        )

        settingsManager.settings.postureTimer = TimerConfiguration(
            enabled: postureEnabled,
            intervalSeconds: postureIntervalMinutes * 60
        )

        settingsManager.settings.launchAtLogin = launchAtLogin
        settingsManager.settings.subtleReminderSize = subtleReminderSize
        settingsManager.settings.hasCompletedOnboarding = true

        // Apply launch at login setting
        do {
            if launchAtLogin {
                try LaunchAtLoginManager.enable()
            } else {
                try LaunchAtLoginManager.disable()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }

        // Close window with standard macOS animation
        dismiss()

        // After a brief delay, trigger the menu bar extra to open
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
