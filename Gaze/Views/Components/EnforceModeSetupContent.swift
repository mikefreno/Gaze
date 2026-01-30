//
//  EnforceModeSetupContent.swift
//  Gaze
//
//  Created by Mike Freno on 1/30/26.
//

import AVFoundation
import SwiftUI

struct EnforceModeSetupContent: View {
    @Bindable var settingsManager: SettingsManager
    @ObservedObject var cameraService = CameraAccessService.shared
    @ObservedObject var eyeTrackingService = EyeTrackingService.shared
    @ObservedObject var enforceModeService = EnforceModeService.shared
    @ObservedObject var calibratorService = CalibratorService.shared
    @Environment(\.isCompactLayout) private var isCompact

    let presentation: SetupPresentation
    @Binding var isTestModeActive: Bool
    @Binding var cachedPreviewLayer: AVCaptureVideoPreviewLayer?
    @Binding var showAdvancedSettings: Bool
    @Binding var showCalibrationWindow: Bool
    @Binding var isViewActive: Bool
    let isProcessingToggle: Bool
    let handleEnforceModeToggle: (Bool) -> Void

    private var cameraHardwareAvailable: Bool {
        cameraService.hasCameraHardware
    }

    private var sectionCornerRadius: CGFloat {
        presentation.isCard ? 10 : 12
    }

    private var sectionPadding: CGFloat {
        presentation.isCard ? 10 : 16
    }

    private var headerFont: Font {
        presentation.isCard ? .subheadline : .headline
    }

    private var iconSize: CGFloat {
        presentation.isCard ? AdaptiveLayout.Font.cardIconSmall : AdaptiveLayout.Font.cardIcon
    }

    var body: some View {
        VStack(spacing: presentation.isCard ? 10 : 24) {
            if presentation.isCard {
                Image(systemName: "video.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color.accentColor)

                Text("Enforce Mode")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Use your camera to ensure you take breaks")
                .font(presentation.isCard ? .subheadline : (isCompact ? .subheadline : .title3))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if presentation.isCard {
                Spacer(minLength: 0)
            }

            VStack(spacing: presentation.isCard ? 10 : 20) {
                enforceModeToggleView
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

            if presentation.isCard {
                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $showCalibrationWindow) {
            EyeTrackingCalibrationView()
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
        .controlSize(presentation.isCard ? .regular : .large)
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

            if calibratorService.calibrationData.isComplete {
                VStack(alignment: .leading, spacing: 8) {
                    Text(calibratorService.getCalibrationSummary())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if calibratorService.needsRecalibration() {
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
                        calibratorService.calibrationData.isComplete
                            ? "Recalibrate" : "Run Calibration")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(sectionPadding)
        .glassEffectIfAvailable(
            GlassStyle.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: sectionCornerRadius)
        )
    }

    private var testModePreviewView: some View {
        VStack(spacing: 16) {
            let lookingAway = !eyeTrackingService.userLookingAtScreen
            let borderColor: NSColor = lookingAway ? .systemGreen : .systemRed

            let previewLayer = eyeTrackingService.previewLayer ?? cachedPreviewLayer

            if let layer = previewLayer {
                ZStack {
                    CameraPreviewView(previewLayer: layer, borderColor: borderColor)
                    PupilOverlayView(eyeTrackingService: eyeTrackingService)

                    VStack {
                        HStack {
                            Spacer()
                            GazeOverlayView(eyeTrackingService: eyeTrackingService)
                        }
                        Spacer()
                    }
                }
                .frame(height: presentation.isCard ? 180 : (isCompact ? 200 : 300))
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
                .onAppear {
                    if cachedPreviewLayer == nil {
                        cachedPreviewLayer = eyeTrackingService.previewLayer
                    }
                }
            }
        }
    }

    private var cameraStatusView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Camera Access")
                    .font(headerFont)

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
                    Task { @MainActor in
                        do {
                            try await cameraService.requestCameraAccess()
                        } catch {
                            print("⚠️ Camera access failed: \(error.localizedDescription)")
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(presentation.isCard ? .small : .regular)
            }
        }
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
    }

    private var eyeTrackingStatusView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eye Tracking Status")
                .font(headerFont)

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
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
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
                    .font(headerFont)
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
        .padding(sectionPadding)
        .glassEffectIfAvailable(
            GlassStyle.regular.tint(.blue.opacity(0.1)), in: .rect(cornerRadius: sectionCornerRadius)
        )
    }

    private func privacyBullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.blue)
            Text(text)
        }
    }

    private var enforceModeToggleView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Enable Enforce Mode")
                    .font(headerFont)
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
                        settingsManager.isTimerEnabled(for: .lookAway)
                            || settingsManager.isTimerEnabled(for: .blink)
                            || settingsManager.isTimerEnabled(for: .posture)
                    },
                    set: { newValue in
                        guard !isProcessingToggle else { return }
                        handleEnforceModeToggle(newValue)
                    }
                )
            )
            .labelsHidden()
            .disabled(isProcessingToggle || !cameraHardwareAvailable)
            .controlSize(presentation.isCard ? .small : (isCompact ? .small : .regular))
        }
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
    }

    private var trackingConstantsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tracking Sensitivity")
                    .font(headerFont)
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
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
    }
}
