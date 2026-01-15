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
    @ObservedObject var trackingConstants = EyeTrackingConstants.shared

    @State private var isProcessingToggle = false
    @State private var isTestModeActive = false
    @State private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var showDebugView = false
    @State private var isViewActive = false
    @State private var showAdvancedSettings = false
    @State private var showCalibrationWindow = false
    @ObservedObject var calibrationManager = CalibrationManager.shared

    var body: some View {
        ScrollView {
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
                            calibrationSection
                        }

                        if isTestModeActive && enforceModeService.isCameraActive {
                            testModePreviewView
                            trackingConstantsView
                        } else {
                            if enforceModeService.isCameraActive && !isTestModeActive {
                                trackingConstantsView
                                eyeTrackingStatusView
                                #if DEBUG
                                    if showDebugView {
                                        debugEyeTrackingView
                                    }
                                #endif
                            } else if enforceModeService.isEnforceModeEnabled {
                                cameraPendingView
                            }

                            privacyInfoView
                        }
                    }
                }

                Spacer()
            }
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
                    .foregroundColor(.blue)
                Text("Eye Tracking Calibration")
                    .font(.headline)
            }

            if calibrationManager.calibrationData.isComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calibrationManager.getCalibrationSummary())
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if calibrationManager.needsRecalibration() {
                        Label(
                            "Calibration expired - recalibration recommended",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.caption)
                        .foregroundColor(.orange)
                    } else {
                        Label("Calibration active and valid", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            } else {
                Text("Not calibrated - using default thresholds")
                    .font(.caption)
                    .foregroundColor(.secondary)
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
                CameraPreviewView(previewLayer: layer, borderColor: borderColor)
                    .frame(height: 300)
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
                /*.foregroundColor(lookingAway ? .green : .orange)*/
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
                    .foregroundColor(eyeTrackingService.enableDebugLogging ? .orange : .secondary)
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
                    .foregroundColor(.secondary)

                if let leftRatio = eyeTrackingService.debugLeftPupilRatio,
                    let rightRatio = eyeTrackingService.debugRightPupilRatio
                {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Left Pupil: \(String(format: "%.3f", leftRatio))")
                                .font(.caption2)
                                .foregroundColor(
                                    !trackingConstants.minPupilEnabled
                                        && !trackingConstants.maxPupilEnabled
                                        ? .secondary
                                        : (leftRatio < trackingConstants.minPupilRatio
                                            || leftRatio > trackingConstants.maxPupilRatio)
                                            ? .orange : .green
                                )
                            Text("Right Pupil: \(String(format: "%.3f", rightRatio))")
                                .font(.caption2)
                                .foregroundColor(
                                    !trackingConstants.minPupilEnabled
                                        && !trackingConstants.maxPupilEnabled
                                        ? .secondary
                                        : (rightRatio < trackingConstants.minPupilRatio
                                            || rightRatio > trackingConstants.maxPupilRatio)
                                            ? .orange : .green
                                )
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(
                                "Range: \(String(format: "%.2f", trackingConstants.minPupilRatio)) - \(String(format: "%.2f", trackingConstants.maxPupilRatio))"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            let bothEyesOut =
                                (leftRatio < trackingConstants.minPupilRatio
                                    || leftRatio > trackingConstants.maxPupilRatio)
                                && (rightRatio < trackingConstants.minPupilRatio
                                    || rightRatio > trackingConstants.maxPupilRatio)
                            Text(bothEyesOut ? "Both Out ⚠️" : "In Range ✓")
                                .font(.caption2)
                                .foregroundColor(bothEyesOut ? .orange : .green)
                        }
                    }
                } else {
                    Text("Pupil data unavailable")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let yaw = eyeTrackingService.debugYaw,
                    let pitch = eyeTrackingService.debugPitch
                {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Yaw: \(String(format: "%.3f", yaw))")
                                .font(.caption2)
                                .foregroundColor(
                                    !trackingConstants.yawEnabled
                                        ? .secondary
                                        : abs(yaw) > trackingConstants.yawThreshold
                                            ? .orange : .green
                                )
                            Text("Pitch: \(String(format: "%.3f", pitch))")
                                .font(.caption2)
                                .foregroundColor(
                                    !trackingConstants.pitchUpEnabled
                                        && !trackingConstants.pitchDownEnabled
                                        ? .secondary
                                        : (pitch > trackingConstants.pitchUpThreshold
                                            || pitch < trackingConstants.pitchDownThreshold)
                                            ? .orange : .green
                                )
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(
                                "Yaw Max: \(String(format: "%.2f", trackingConstants.yawThreshold))"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            Text(
                                "Pitch: \(String(format: "%.2f", trackingConstants.pitchDownThreshold)) to \(String(format: "%.2f", trackingConstants.pitchUpThreshold))"
                            )
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(.top, 4)

            if showAdvancedSettings {
                VStack(spacing: 16) {
                    // Yaw Threshold
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $trackingConstants.yawEnabled)
                                .labelsHidden()
                            Text("Yaw Threshold (Head Turn)")
                                .foregroundColor(
                                    trackingConstants.yawEnabled ? .primary : .secondary)
                            Spacer()
                            Text(String(format: "%.2f rad", trackingConstants.yawThreshold))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $trackingConstants.yawThreshold, in: 0.1...0.8, step: 0.05)
                            .disabled(!trackingConstants.yawEnabled)
                        Text("Lower = more sensitive to head turning")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Pitch Up Threshold
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $trackingConstants.pitchUpEnabled)
                                .labelsHidden()
                            Text("Pitch Up Threshold (Looking Up)")
                                .foregroundColor(
                                    trackingConstants.pitchUpEnabled ? .primary : .secondary)
                            Spacer()
                            Text(String(format: "%.2f rad", trackingConstants.pitchUpThreshold))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(
                            value: $trackingConstants.pitchUpThreshold, in: -0.2...0.5, step: 0.05
                        )
                        .disabled(!trackingConstants.pitchUpEnabled)
                        Text("Lower = more sensitive to looking up")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Pitch Down Threshold
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $trackingConstants.pitchDownEnabled)
                                .labelsHidden()
                            Text("Pitch Down Threshold (Looking Down)")
                                .foregroundColor(
                                    trackingConstants.pitchDownEnabled ? .primary : .secondary)
                            Spacer()
                            Text(String(format: "%.2f rad", trackingConstants.pitchDownThreshold))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(
                            value: $trackingConstants.pitchDownThreshold, in: -0.8...0.0, step: 0.05
                        )
                        .disabled(!trackingConstants.pitchDownEnabled)
                        Text("Higher = more sensitive to looking down")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Min Pupil Ratio
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $trackingConstants.minPupilEnabled)
                                .labelsHidden()
                            Text("Min Pupil Ratio (Looking Right)")
                                .foregroundColor(
                                    trackingConstants.minPupilEnabled ? .primary : .secondary)
                            Spacer()
                            Text(String(format: "%.2f", trackingConstants.minPupilRatio))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $trackingConstants.minPupilRatio, in: 0.2...0.5, step: 0.01)
                            .disabled(!trackingConstants.minPupilEnabled)
                        Text("Higher = more sensitive to looking right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Max Pupil Ratio
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $trackingConstants.maxPupilEnabled)
                                .labelsHidden()
                            Text("Max Pupil Ratio (Looking Left)")
                                .foregroundColor(
                                    trackingConstants.maxPupilEnabled ? .primary : .secondary)
                            Spacer()
                            Text(String(format: "%.2f", trackingConstants.maxPupilRatio))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(value: $trackingConstants.maxPupilRatio, in: 0.5...0.8, step: 0.01)
                            .disabled(!trackingConstants.maxPupilEnabled)
                        Text("Lower = more sensitive to looking left")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // Eye Closed Threshold
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle("", isOn: $trackingConstants.eyeClosedEnabled)
                                .labelsHidden()
                            Text("Eye Closed Threshold")
                                .foregroundColor(
                                    trackingConstants.eyeClosedEnabled ? .primary : .secondary)
                            Spacer()
                            Text(String(format: "%.3f", trackingConstants.eyeClosedThreshold))
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(trackingConstants.eyeClosedThreshold) },
                                set: { trackingConstants.eyeClosedThreshold = CGFloat($0) }
                            ), in: 0.01...0.1, step: 0.005
                        )
                        .disabled(!trackingConstants.eyeClosedEnabled)
                        Text("Lower = more sensitive to eye closure")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    // Reset button
                    Button(action: {
                        trackingConstants.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
                .foregroundColor(.blue)

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
            .foregroundColor(.secondary)
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
    }
}

#Preview {
    EnforceModeSetupView(settingsManager: SettingsManager.shared)
}
