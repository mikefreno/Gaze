//
//  OnboardingContainerView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

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
    
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                WelcomeView(onContinue: { currentPage = 1 })
                    .tag(0)
                
                LookAwaySetupView(
                    enabled: $lookAwayEnabled,
                    intervalMinutes: $lookAwayIntervalMinutes,
                    countdownSeconds: $lookAwayCountdownSeconds,
                    onContinue: { currentPage = 2 }
                )
                .tag(1)
                
                BlinkSetupView(
                    enabled: $blinkEnabled,
                    intervalMinutes: $blinkIntervalMinutes,
                    onContinue: { currentPage = 3 }
                )
                .tag(2)
                
                PostureSetupView(
                    enabled: $postureEnabled,
                    intervalMinutes: $postureIntervalMinutes,
                    onContinue: { currentPage = 4 }
                )
                .tag(3)
                
                CompletionView(
                    onComplete: {
                        completeOnboarding()
                    }
                )
                .tag(4)
            }
            .tabViewStyle(.automatic)
            
            // Page indicator
            Text("\(currentPage + 1)/5")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 20)
        }
    }
    
    private func completeOnboarding() {
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
        
        settingsManager.settings.hasCompletedOnboarding = true
    }
}

#Preview {
    OnboardingContainerView(settingsManager: SettingsManager.shared)
}
