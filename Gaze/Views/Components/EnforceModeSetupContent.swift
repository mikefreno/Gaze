//
//  EnforceModeSetupContent.swift
//  Gaze
//
//  Created by Mike Freno on 1/30/26.
//

import AVFoundation
import AppKit
import SwiftUI

struct EnforceModeSetupContent: View {
    @Bindable var settingsManager: SettingsManager
    @ObservedObject var cameraService = CameraAccessService.shared
    @ObservedObject var eyeTrackingService = EyeTrackingService.shared
    @ObservedObject var enforceModeService = EnforceModeService.shared
    @ObservedObject var calibrationService = EnforceModeCalibrationService.shared
    @Environment(\.isCompactLayout) private var isCompact

    let presentation: SetupPresentation
    @Binding var isTestModeActive: Bool
    @Binding var cachedPreviewLayer: AVCaptureVideoPreviewLayer?
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
                calibrationActionView
                privacyInfoView
            }

            if presentation.isCard {
                Spacer(minLength: 0)
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
        .controlSize(presentation.isCard ? .regular : .large)
    }

    private var testModePreviewView: some View {
        VStack(spacing: 16) {
            let lookingAway = eyeTrackingService.trackingResult.gazeState == .lookingAway
            let borderColor: NSColor = lookingAway ? .systemGreen : .systemRed

            let previewLayer = eyeTrackingService.previewLayer ?? cachedPreviewLayer

            if let layer = previewLayer {
                ZStack {
                    CameraPreviewView(previewLayer: layer, borderColor: borderColor)

                    GeometryReader { geometry in
                        EyeTrackingDebugOverlayView(
                            debugState: eyeTrackingService.debugState,
                            viewSize: geometry.size
                        )
                    }
                }
                .frame(height: presentation.isCard ? 180 : (isCompact ? 200 : 300))
                .glassEffectIfAvailable(
                    GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius)
                )
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
                    isActive: eyeTrackingService.trackingResult.faceDetected,
                    icon: "person.fill"
                )

                statusIndicator(
                    title: "Looking Away",
                    isActive: eyeTrackingService.trackingResult.gazeState == .lookingAway,
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
            GlassStyle.regular.tint(.blue.opacity(0.1)),
            in: .rect(cornerRadius: sectionCornerRadius)
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
                        enforceModeService.isEnforceModeEnabled
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
                Text("Tracking Status")
                    .font(headerFont)
            }

            let gazeState = eyeTrackingService.trackingResult.gazeState
            let stateLabel: String = {
                switch gazeState {
                case .lookingAway:
                    return "Looking Away"
                case .lookingAtScreen:
                    return "Looking At Screen"
                case .unknown:
                    return "Unknown"
                }
            }()

            VStack(alignment: .leading, spacing: 8) {

                HStack(spacing: 12) {
                    Text("Gaze:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(stateLabel)
                        .font(.caption2)
                        .foregroundStyle(gazeState == .lookingAway ? .green : .secondary)
                }

                HStack(spacing: 12) {
                    Text("Confidence:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.2f", eyeTrackingService.trackingResult.confidence))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if let faceWidth = eyeTrackingService.debugState.faceWidthRatio {
                    HStack(spacing: 12) {
                        Text("Face Width:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.3f", faceWidth))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let horizontal = eyeTrackingService.debugState.normalizedHorizontal,
                    let vertical = eyeTrackingService.debugState.normalizedVertical
                {
                    HStack(spacing: 12) {
                        Text("Ratios:")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("H \(String(format: "%.3f", horizontal))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("V \(String(format: "%.3f", vertical))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
    }

    private var calibrationActionView: some View {
        Button(action: {
            calibrationService.presentOverlay()
            Task { @MainActor in
                await enforceModeService.startTestMode()
            }
        }) {
            HStack {
                Image(systemName: "target")
                Text("Calibrate Eye Tracking")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }


}
