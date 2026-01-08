//
//  OnboardingContainerView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI
import AppKit

// NSVisualEffectView wrapper for SwiftUI
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
    @State private var blinkEnabled = true
    @State private var blinkIntervalMinutes = 5
    @State private var postureEnabled = true
    @State private var postureIntervalMinutes = 30
    @State private var launchAtLogin = false
    @State private var isAnimatingOut = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Semi-transparent background with blur
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    WelcomeView(
                        onContinue: { currentPage = 1 }
                    )
                    .tag(0)
                    .tabItem {
                        Image(systemName: "hand.wave.fill")
                    }
                    
                    LookAwaySetupView(
                        enabled: $lookAwayEnabled,
                        intervalMinutes: $lookAwayIntervalMinutes,
                        countdownSeconds: $lookAwayCountdownSeconds,
                        onContinue: { currentPage = 2 },
                        onBack: { currentPage = 0 }
                    )
                    .tag(1)
                    .tabItem {
                        Image(systemName: "eye.fill")
                    }
                    
                    BlinkSetupView(
                        enabled: $blinkEnabled,
                        intervalMinutes: $blinkIntervalMinutes,
                        onContinue: { currentPage = 3 },
                        onBack: { currentPage = 1 }
                    )
                    .tag(2)
                    .tabItem {
                        Image(systemName: "eye.circle.fill")
                    }
                    
                    PostureSetupView(
                        enabled: $postureEnabled,
                        intervalMinutes: $postureIntervalMinutes,
                        onContinue: { currentPage = 4 },
                        onBack: { currentPage = 2 }
                    )
                    .tag(3)
                    .tabItem {
                        Image(systemName: "figure.stand")
                    }
                    
                    SettingsOnboardingView(
                        launchAtLogin: $launchAtLogin,
                        onContinue: { currentPage = 5 },
                        onBack: { currentPage = 3 }
                    )
                    .tag(4)
                    .tabItem {
                        Image(systemName: "gearshape.fill")
                    }
                    
                    CompletionView(
                        onComplete: {
                            completeOnboarding()
                        },
                        onBack: { currentPage = 4 }
                    )
                    .tag(5)
                    .tabItem {
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
                .tabViewStyle(.automatic)
            }
        }
        .opacity(isAnimatingOut ? 0 : 1)
        .scaleEffect(isAnimatingOut ? 0.3 : 1.0)
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
        
        // Perform vacuum animation
        performVacuumAnimation()
    }
    
    private func performVacuumAnimation() {
        // Get the NSWindow reference
        guard let window = NSApplication.shared.windows.first(where: { $0.isVisible && $0.contentView != nil }) else {
            // Fallback: just dismiss without animation
            dismiss()
            return
        }
        
        // Get menubar icon position from AppDelegate
        let appDelegate = NSApplication.shared.delegate as? AppDelegate
        let targetFrame = appDelegate?.getMenuBarIconPosition()
        
        // Calculate target position (menubar icon or top-center as fallback)
        let targetRect: NSRect
        if let menuBarFrame = targetFrame {
            // Use menubar icon position
            targetRect = NSRect(
                x: menuBarFrame.midX,
                y: menuBarFrame.midY,
                width: 0,
                height: 0
            )
        } else {
            // Fallback to top-center of screen
            let screen = NSScreen.main?.frame ?? .zero
            targetRect = NSRect(
                x: screen.midX,
                y: screen.maxY,
                width: 0,
                height: 0
            )
        }
        
        // Start SwiftUI animation for visual effects
        withAnimation(.easeInOut(duration: 0.7)) {
            isAnimatingOut = true
        }
        
        // Animate window frame using AppKit
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.7
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().setFrame(targetRect, display: true)
            window.animator().alphaValue = 0
        }, completionHandler: {
            // Close window after animation completes
            self.dismiss()
            window.close()
        })
    }
}

#Preview {
    OnboardingContainerView(settingsManager: SettingsManager.shared)
}
