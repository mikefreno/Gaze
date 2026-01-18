//
//  AdditionalModifiersView.swift
//  Gaze
//
//  Created by Mike Freno on 1/18/26.
//

import SwiftUI

struct OnboardingVisualEffectView: NSViewRepresentable {
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

struct AdditionalModifiersView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var currentIndex = 0
    
    var body: some View {
        ZStack {
            OnboardingVisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Additional Modifiers")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                
                Spacer()
                
                // Card Stack - simplified version for now
                VStack(spacing: 30) {
                    if currentIndex == 0 {
                        EnforceModeSetupView(settingsManager: settingsManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        SmartModeSetupView(settingsManager: settingsManager)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(height: 500)
                
                Spacer()
                
                // Navigation Arrows
                HStack(spacing: 40) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentIndex = 0
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                            .foregroundColor(.primary)
                    }
                    .disabled(currentIndex == 0)
                    .buttonStyle(.plain)
                    
                    Text("\(currentIndex + 1) of 2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentIndex = 1
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.gray.opacity(0.2)))
                            .foregroundColor(.primary)
                    }
                    .disabled(currentIndex == 1)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 30)
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
    }
}

#Preview("Additional Modifiers View") {
    AdditionalModifiersView(settingsManager: SettingsManager.shared)
}