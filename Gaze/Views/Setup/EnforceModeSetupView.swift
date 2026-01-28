//
//  EnforceModeSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import Foundation
import SwiftUI

struct EnforceModeSetupView: View {
    @Bindable var settingsManager: SettingsManager
    @ObservedObject var cameraService = CameraAccessService.shared
    @ObservedObject var eyeTrackingService = EyeTrackingService.shared
    @ObservedObject var enforceModeService = EnforceModeService.shared
    @Environment(\.isCompactLayout) private var isCompact

    @State private var isProcessingToggle = false
    @State private var isTestModeActive = false
    @State private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var showDebugView = false
    @State private var isViewActive = false
    @State private var showAdvancedSettings = false
    @State private var showCalibrationWindow = false
    @ObservedObject var calibrationManager = CalibrationManager.shared

    private var cameraHardwareAvailable: Bool {
        cameraService.hasCameraHardware
    }

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "video.fill", title: "Enforce Mode", color: .accentColor)

            Spacer()

            VStack(spacing: isCompact ? 16 : 30) {
                Text("Use your camera to ensure you take breaks")
                    .font(isCompact ? .subheadline : .title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: isCompact ? 12 : 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Enforce Mode")
                                .font(isCompact ? .subheadline : .headline)
                            if !cameraHardwareAvailable {
                                Text("No camera hardware detected")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            } else {
                                Text("Camera activates 3 seconds before lookaway reminders")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
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
                        .disabled(isProcessingToggle || !cameraHardwareAvailable)
                        .controlSize(isCompact ? .small : .regular)
                    }
                    .padding(isCompact ? 10 : 16)
                    .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

                    cameraStatusView

                    if enforceModeService.isEnforceModeEnabled {
                        testModeButton
                    }
                    if isTestModeActive && enforceModeService.isCameraActive {
                        testModePreviewView
                        trackingConstantsView
                    } else if enforceModeService.isCameraActive && !isTestModeActive {
                        eyeTrackingStatusView
                        trackingConstantsView
                    }
                    privacyInfoView
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
        .onAppear {
            isViewActive = true
        }
        .onDisappear {
            isViewActive = false
            // If the view disappeared and camera is still active, stop it
            if enforceModeService.isCameraActive {
                print("👁️ EnforceModeSetupView disappeared, stopping camera preview")
                enforceModeService.stopCamera()
            }
        }
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

    private var calibrationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "target")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Eye Tracking Calibration")
                    .font(.headline)
            }

            if calibrationManager.calibrationData.isComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calibrationManager.getCalibrationSummary())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if calibrationManager.needsRecalibration() {
                        Label(
                            "Calibration expired - recalibration recommended",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    } else {
                        Label("Calibration active and valid", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            } else {
                Text("Not calibrated - using default thresholds")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                showCalibrationWindow = true
            }) {
                HStack {
                    Image(systemName: "target")
                    Text(
                        calibrationManager.calibrationData.isComplete
                            ? "Recalibrate" : "Run Calibration")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding()
        .glassEffectIfAvailable(
            GlassStyle.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: 12)
        )
        .sheet(isPresented: $showCalibrationWindow) {
            EyeTrackingCalibrationView()
        }
    }

    private var testModePreviewView: some View {
        VStack(spacing: 16) {
            let lookingAway = !eyeTrackingService.userLookingAtScreen
            let borderColor: NSColor = lookingAway ? .systemGreen : .systemRed

            // Cache the preview layer to avoid recreating it
            let previewLayer = eyeTrackingService.previewLayer ?? cachedPreviewLayer

            if let layer = previewLayer {
                ZStack {
                    CameraPreviewView(previewLayer: layer, borderColor: borderColor)

                    // Pupil detection overlay (drawn on video)
                    PupilOverlayView(eyeTrackingService: eyeTrackingService)

                    // Debug info overlay (top-right corner)
                    VStack {
                        HStack {
                            Spacer()
                            GazeOverlayView(eyeTrackingService: eyeTrackingService)
                        }
                        Spacer()
                    }
                }
                .frame(height: isCompact ? 200 : 300)
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
                .onAppear {
                    if cachedPreviewLayer == nil {
                        cachedPreviewLayer = eyeTrackingService.previewLayer
                    }
                }

                /*VStack(alignment: .leading, spacing: 12) {*/
                /*Text("Live Tracking Status")*/
                /*.font(.headline)*/

                /*HStack(spacing: 20) {*/
                /*statusIndicator(*/
                /*title: "Face Detected",*/
                /*isActive: eyeTrackingService.faceDetected,*/
                /*icon: "person.fill"*/
                /*)*/

                /*statusIndicator(*/
                /*title: "Looking Away",*/
                /*isActive: !eyeTrackingService.userLookingAtScreen,*/
                /*icon: "arrow.turn.up.right"*/
                /*)*/
                /*}*/

                /*Text(*/
                /*lookingAway*/
                /*? "✓ Break compliance detected" : "⚠️ Please look away from screen"*/
                /*)*/
                /*.font(.caption)*/
                /*.foregroundStyle(lookingAway ? .green : .orange)*/
                /*.frame(maxWidth: .infinity, alignment: .center)*/
                /*.padding(.top, 4)*/
                /*}*/
                /*.padding()*/
                /*.glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))*/
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
                        .foregroundStyle(.green)
                } else if let error = cameraService.cameraError {
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

    private func statusIndicator(title: String, isActive: Bool, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isActive ? .green : .secondary)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var privacyInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                Text("Privacy Information")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                privacyBullet("All processing happens on-device")
                privacyBullet("No images are stored or transmitted")
                privacyBullet("Camera only active during lookaway reminders (3 second window)")
                privacyBullet("You can always force quit with cmd+q")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffectIfAvailable(
            GlassStyle.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: 12))
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.blue)
            Text(text)
        }
    }

    private func handleEnforceModeToggle(enabled: Bool) {
        print("🎛️ handleEnforceModeToggle called with enabled: \(enabled)")
        isProcessingToggle = true

        Task { @MainActor in
            defer { isProcessingToggle = false }

            if enabled {
                guard cameraHardwareAvailable else {
                    print("⚠️ Cannot enable enforce mode - no camera hardware")
                    settingsManager.settings.enforcementMode = false
                    return
                }
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
                // Clean up camera when disabling enforce mode
                if enforceModeService.isCameraActive {
                    print("👁️ Cleaning up camera on enforce mode disable")
                    enforceModeService.stopCamera()
                }
            }
        }
    }

    private var trackingConstantsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tracking Sensitivity")
                    .font(.headline)
                Spacer()
                Button(action: {
                    eyeTrackingService.enableDebugLogging.toggle()
                }) {
                    Image(
                        systemName: eyeTrackingService.enableDebugLogging
                            ? "ant.circle.fill" : "ant.circle"
                    )
                    .foregroundStyle(eyeTrackingService.enableDebugLogging ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle console debug logging")

                Button(showAdvancedSettings ? "Hide Settings" : "Show Settings") {
                    withAnimation {
                        showAdvancedSettings.toggle()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Debug info always visible when tracking
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Values:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                if let leftRatio = eyeTrackingService.debugLeftPupilRatio,
                    let rightRatio = eyeTrackingService.debugRightPupilRatio
                {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Left Pupil: \(String(format: "%.3f", leftRatio))")
                                .font(.caption2)
                                .foregroundStyle(
                                    !EyeTrackingConstants.minPupilEnabled
                                        && !EyeTrackingConstants.maxPupilEnabled
                                        ? .secondary
                                        : (leftRatio < EyeTrackingConstants.minPupilRatio
                                            || leftRatio > EyeTrackingConstants.maxPupilRatio)
                                            ? Color.orange : Color.green
                                )
                            Text("Right Pupil: \(String(format: "%.3f", rightRatio))")
                                .font(.caption2)
                                .foregroundStyle(
                                    !EyeTrackingConstants.minPupilEnabled
                                        && !EyeTrackingConstants.maxPupilEnabled
                                        ? .secondary
                                        : (rightRatio < EyeTrackingConstants.minPupilRatio
                                            || rightRatio > EyeTrackingConstants.maxPupilRatio)
                                            ? Color.orange : Color.green
                                )
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(
                                "Range: \(String(format: "%.2f", EyeTrackingConstants.minPupilRatio)) - \(String(format: "%.2f", EyeTrackingConstants.maxPupilRatio))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            let bothEyesOut =
                                (leftRatio < EyeTrackingConstants.minPupilRatio
                                    || leftRatio > EyeTrackingConstants.maxPupilRatio)
                                && (rightRatio < EyeTrackingConstants.minPupilRatio
                                    || rightRatio > EyeTrackingConstants.maxPupilRatio)
                            Text(bothEyesOut ? "Both Out ⚠️" : "In Range ✓")
                                .font(.caption2)
                                .foregroundStyle(bothEyesOut ? .orange : .green)
                        }
                    }
                } else {
                    Text("Pupil data unavailable")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let yaw = eyeTrackingService.debugYaw,
                    let pitch = eyeTrackingService.debugPitch
                {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Yaw: \(String(format: "%.3f", yaw))")
                                .font(.caption2)
                                .foregroundStyle(
                                    !EyeTrackingConstants.yawEnabled
                                        ? .secondary
                                        : abs(yaw) > EyeTrackingConstants.yawThreshold
                                            ? Color.orange : Color.green
                                )
                            Text("Pitch: \(String(format: "%.3f", pitch))")
                                .font(.caption2)
                                .foregroundStyle(
                                    !EyeTrackingConstants.pitchUpEnabled
                                        && !EyeTrackingConstants.pitchDownEnabled
                                        ? .secondary
                                        : (pitch > EyeTrackingConstants.pitchUpThreshold
                                            || pitch < EyeTrackingConstants.pitchDownThreshold)
                                            ? Color.orange : Color.green
                                )
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(
                                "Yaw Max: \(String(format: "%.2f", EyeTrackingConstants.yawThreshold))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            Text(
                                "Pitch: \(String(format: "%.2f", EyeTrackingConstants.pitchDownThreshold)) to \(String(format: "%.2f", EyeTrackingConstants.pitchUpThreshold))"
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)

            if showAdvancedSettings {
                VStack(spacing: 16) {
                    // Display the current constant values
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Current Threshold Values:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("Yaw Threshold:")
                            Spacer()
                            Text("\(String(format: "%.2f", EyeTrackingConstants.yawThreshold)) rad")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Pitch Up Threshold:")
                            Spacer()
                            Text(
                                "\(String(format: "%.2f", EyeTrackingConstants.pitchUpThreshold)) rad"
                            )
                            .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Pitch Down Threshold:")
                            Spacer()
                            Text(
                                "\(String(format: "%.2f", EyeTrackingConstants.pitchDownThreshold)) rad"
                            )
                            .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Min Pupil Ratio:")
                            Spacer()
                            Text("\(String(format: "%.2f", EyeTrackingConstants.minPupilRatio))")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Max Pupil Ratio:")
                            Spacer()
                            Text("\(String(format: "%.2f", EyeTrackingConstants.maxPupilRatio))")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Eye Closed Threshold:")
                            Spacer()
                            Text(
                                "\(String(format: "%.3f", EyeTrackingConstants.eyeClosedThreshold))"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }

    private var debugEyeTrackingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Eye Tracking Data")
                .font(.headline)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                Text("Face Detected: \(eyeTrackingService.faceDetected ? "Yes" : "No")")
                    .font(.caption)

                Text("Looking at Screen: \(eyeTrackingService.userLookingAtScreen ? "Yes" : "No")")
                    .font(.caption)

                Text("Eyes Closed: \(eyeTrackingService.isEyesClosed ? "Yes" : "No")")
                    .font(.caption)

                if eyeTrackingService.faceDetected {
                    Text("Yaw: 0.0")
                        .font(.caption)

                    Text("Roll: 0.0")
                        .font(.caption)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    EnforceModeSetupView(settingsManager: SettingsManager.shared)
}
