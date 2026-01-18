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
                
                // Main content area with stacking effect
                HStack(spacing: 0) {
                    // Smart Mode Card (stacked behind, 50% width, offset 10% from right)
                    ZStack {
                        // Background card with shadow and rounded corners
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.8))
                            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                            .frame(width: 500, height: 500) // 50% of 1000px width
                            .offset(x: 100) // 10% offset from right (1000 * 0.1 = 100)
                        
                        // Smart mode content
                        SmartModeSetupView(settingsManager: settingsManager)
                            .padding(20)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
                    
                    // Enforce Mode Card (in front)
                    VStack(spacing: 24) {
                        SetupHeader(icon: "video.fill", title: "Enforce Mode", color: .accentColor)
                        
                        Text("Use your camera to ensure you take breaks")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 10)
                        
                        VStack(spacing: 20) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Enable Enforce Mode")
                                        .font(.headline)
                                    Text("Camera activates 3 seconds before lookaway reminders")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: {
                                            settingsManager.settings.enforcementMode
                                        },
                                        set: { newValue in
                                            print("🎛️ Toggle changed to: \(newValue)")
                                            settingsManager.settings.enforcementMode = newValue
                                        }
                                    )
                                )
                                .labelsHidden()
                            }
                            .padding()
                            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
                            
                            // Camera access status display
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Camera Access")
                                        .font(.headline)
                                    
                                    if CameraAccessService.shared.isCameraAuthorized {
                                        Label("Authorized", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                    } else if let error = CameraAccessService.shared.cameraError {
                                        Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    } else {
                                        Label("Not authorized", systemImage: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if !CameraAccessService.shared.isCameraAuthorized {
                                    Button("Request Access") {
                                        print("📷 Request Access button clicked")
                                        Task { @MainActor in
                                            do {
                                                try await CameraAccessService.shared.requestCameraAccess()
                                                print("✓ Camera access granted via button")
                                            } catch {
                                                print("⚠️ Camera access failed: \(error.localizedDescription)")
                                            }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding()
                            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
                        }
                    }
                    .frame(width: 500) // 50% width
                    .zIndex(1)
                }
                
                Spacer()
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