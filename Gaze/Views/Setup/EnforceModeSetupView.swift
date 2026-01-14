//
//  EnforceModeSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import SwiftUI

struct EnforceModeSetupView: View {
    @ObservedObject var settingsManager: SettingsManager
    @ObservedObject var cameraService = CameraAccessService.shared
    @ObservedObject var eyeTrackingService = EyeTrackingService.shared
    @ObservedObject var enforceModeService = EnforceModeService.shared

    @State private var isProcessingToggle = false
    @State private var isTestModeActive = false
    @State private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Image(systemName: "video.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
                Text("Enforce Mode")
                    .font(.system(size: 28, weight: .bold))
            }
            .padding(.top, 20)
            .padding(.bottom, 30)

            Spacer()

            VStack(spacing: 30) {
                Text("Use your camera to ensure you take breaks")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enable Enforce Mode")
                                .font(.headline)
                            Text("Camera activates 3 seconds before lookaway reminders")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                                    guard !isProcessingToggle else {
                                        print("⚠️ Already processing toggle")
                                        return
                                    }
                                    settingsManager.settings.enforcementMode = newValue
                                    handleEnforceModeToggle(enabled: newValue)
                                }
                            )
                        )
                        .labelsHidden()
                        .disabled(isProcessingToggle)
                    }
                    .padding()
                    .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

                    cameraStatusView

                    if enforceModeService.isEnforceModeEnabled {
                        testModeButton
                    }

                    if isTestModeActive && enforceModeService.isCameraActive {
                        testModePreviewView
                    } else {
                        if enforceModeService.isCameraActive && !isTestModeActive {
                            eyeTrackingStatusView
                        } else if enforceModeService.isEnforceModeEnabled {
                            cameraPendingView
                        }

                        privacyInfoView
                    }
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private var testModeButton: some View {
        Button(action: {
            Task { @MainActor in
                if isTestModeActive {
                    enforceModeService.stopTestMode()
                    isTestModeActive = false
                    cachedPreviewLayer = nil
                } else {
                    await enforceModeService.startTestMode()
                    isTestModeActive = enforceModeService.isCameraActive
                    if isTestModeActive {
                        cachedPreviewLayer = eyeTrackingService.previewLayer
                    }
                }
            }
        }) {
            HStack {
                Image(systemName: isTestModeActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title3)
                Text(isTestModeActive ? "Stop Test" : "Test Tracking")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    private var testModePreviewView: some View {
        VStack(spacing: 16) {
            let lookingAway = !eyeTrackingService.userLookingAtScreen
            let borderColor: NSColor = lookingAway ? .systemGreen : .systemRed

            // Cache the preview layer to avoid recreating it
            let previewLayer = eyeTrackingService.previewLayer ?? cachedPreviewLayer

            if let layer = previewLayer {
                CameraPreviewView(previewLayer: layer, borderColor: borderColor)
                    .frame(height: 300)
                    .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
                    .onAppear {
                        if cachedPreviewLayer == nil {
                            cachedPreviewLayer = eyeTrackingService.previewLayer
                        }
                    }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Live Tracking Status")
                        .font(.headline)

                    HStack(spacing: 20) {
                        statusIndicator(
                            title: "Face Detected",
                            isActive: eyeTrackingService.faceDetected,
                            icon: "person.fill"
                        )

                        statusIndicator(
                            title: "Looking Away",
                            isActive: !eyeTrackingService.userLookingAtScreen,
                            icon: "arrow.turn.up.right"
                        )
                    }

                    Text(
                        lookingAway
                            ? "✓ Break compliance detected" : "⚠️ Please look away from screen"
                    )
                    .font(.caption)
                    .foregroundColor(lookingAway ? .green : .orange)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 4)
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
            }
        }
    }

    private var cameraStatusView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Access")
                    .font(.headline)

                if cameraService.isCameraAuthorized {
                    Label("Authorized", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if let error = cameraService.cameraError {
                    Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Label("Not authorized", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if !cameraService.isCameraAuthorized {
                Button("Request Access") {
                    print("📷 Request Access button clicked")
                    Task { @MainActor in
                        do {
                            try await cameraService.requestCameraAccess()
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

    private var eyeTrackingStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eye Tracking Status")
                .font(.headline)

            HStack(spacing: 20) {
                statusIndicator(
                    title: "Face Detected",
                    isActive: eyeTrackingService.faceDetected,
                    icon: "person.fill"
                )

                statusIndicator(
                    title: "Looking Away",
                    isActive: !eyeTrackingService.userLookingAtScreen,
                    icon: "arrow.turn.up.right"
                )
            }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    private var cameraPendingView: some View {
        HStack {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Ready")
                    .font(.headline)
                Text("Will activate 3 seconds before lookaway reminder")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    private func statusIndicator(title: String, isActive: Bool, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? .green : .secondary)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var privacyInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text("Privacy Information")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                privacyBullet("All processing happens on-device")
                privacyBullet("No images are stored or transmitted")
                privacyBullet("Camera only active during lookaway reminders (3 second window)")
                privacyBullet("Eyes closed does not affect countdown")
                privacyBullet("You can disable at any time")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .glassEffectIfAvailable(
            GlassStyle.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: 12))
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.blue)
            Text(text)
        }
    }

    private func handleEnforceModeToggle(enabled: Bool) {
        print("🎛️ handleEnforceModeToggle called with enabled: \(enabled)")
        isProcessingToggle = true

        Task { @MainActor in
            defer { isProcessingToggle = false }

            if enabled {
                print("🎛️ Enabling enforce mode...")
                await enforceModeService.enableEnforceMode()
                print("🎛️ Enforce mode enabled: \(enforceModeService.isEnforceModeEnabled)")

                if !enforceModeService.isEnforceModeEnabled {
                    print("⚠️ Failed to activate, reverting toggle")
                    settingsManager.settings.enforcementMode = false
                }
            } else {
                print("🎛️ Disabling enforce mode...")
                enforceModeService.disableEnforceMode()
            }
        }
    }
}

#Preview {
    EnforceModeSetupView(settingsManager: SettingsManager.shared)
}
