//
//  EnforceModeCalibrationOverlayView.swift
//  Gaze
//
//  Created by Mike Freno on 2/1/26.
//

import SwiftUI

struct EnforceModeCalibrationOverlayView: View {
    @ObservedObject private var calibrationService = EnforceModeCalibrationService.shared
    @ObservedObject private var eyeTrackingService = EyeTrackingService.shared
    @Bindable private var settingsManager = SettingsManager.shared

    @ObservedObject private var enforceModeService = EnforceModeService.shared

    var body: some View {
        ZStack {
            cameraBackground

            switch calibrationService.currentStep {
            case .eyeBox:
                eyeBoxStep
            case .targets:
                targetStep
            case .complete:
                completionStep
            }
        }
    }

    private var eyeBoxStep: some View {
        ZStack {
            VStack(spacing: 20) {
                VStack(spacing: 16) {
                    Text("Adjust Eye Box")
                        .font(.title2)
                        .foregroundStyle(.white)

                    Text(
                        "Use the sliders to fit the boxes around your eyes. It need not be perfect."
                    )
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(.horizontal, 40)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity, alignment: .top)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Width")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Slider(
                        value: $settingsManager.settings.enforceModeEyeBoxWidthFactor,
                        in: 0.12...0.25
                    )

                    Text("Height")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Slider(
                        value: $settingsManager.settings.enforceModeEyeBoxHeightFactor,
                        in: 0.01...0.10
                    )
                }
                .padding(16)
                .background(.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 420)

                Spacer()

                HStack(spacing: 12) {
                    Button("Cancel") {
                        calibrationService.dismissOverlay()
                        enforceModeService.stopTestMode()
                    }
                    .buttonStyle(.bordered)

                    Button("Continue") {
                        calibrationService.advance()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 40)
            }
        }
    }

    private var targetStep: some View {
        ZStack {
            VStack(spacing: 10) {
                HStack {
                    Text("Calibrating...")
                        .foregroundStyle(.white)
                    Spacer()
                    Text(calibrationService.progressText)
                        .foregroundStyle(.white.opacity(0.7))
                }

                ProgressView(value: calibrationService.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                // Gaze validation warning
                if calibrationService.isPausedForGaze {
                    HStack(spacing: 6) {
                        Image(systemName: gazeWarningIcon)
                            .foregroundStyle(.yellow)
                        Text(gazeWarningText)
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                    .transition(.opacity)
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            targetDot

            VStack {
                Spacer()
                HStack(spacing: 12) {
                    Button("Cancel") {
                        calibrationService.dismissOverlay()
                        enforceModeService.stopTestMode()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 40)
        }
        .animation(.easeInOut(duration: 0.2), value: calibrationService.isPausedForGaze)
    }

    private var gazeWarningIcon: String {
        switch calibrationService.gazeValidation {
        case .noFace:
            return "eye.slash"
        case .wrongDirection:
            return "exclamationmark.triangle"
        case .valid:
            return "checkmark.circle"
        }
    }

    private var gazeWarningText: String {
        switch calibrationService.gazeValidation {
        case .noFace:
            return "Face not detected -- paused"
        case .wrongDirection:
            return "Look at the dot -- paused"
        case .valid:
            return ""
        }
    }

    private var completionStep: some View {
        VStack(spacing: 20) {
            Text("Calibration Complete")
                .font(.title2)
                .foregroundStyle(.white)
            Text("Enforce Mode is ready to use.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))

            Button("Done") {
                calibrationService.dismissOverlay()
                enforceModeService.stopTestMode()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var targetDot: some View {
        GeometryReader { geometry in
            let target = calibrationService.currentTarget()
            let center = CGPoint(
                x: geometry.size.width * target.x,
                y: geometry.size.height * target.y
            )
            let dotColor: Color = calibrationService.isPausedForGaze ? .orange : .blue

            ZStack {
                Circle()
                    .fill(dotColor)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(calibrationService.countdownProgress))
                    .stroke(dotColor.opacity(0.8), lineWidth: 8)
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.02), value: calibrationService.countdownProgress)
            }
            .position(center)
            .animation(.easeInOut(duration: 0.3), value: center)
            .animation(.easeInOut(duration: 0.2), value: calibrationService.isPausedForGaze)
        }
        .ignoresSafeArea()
    }

    private var cameraBackground: some View {
        ZStack {
            if let layer = eyeTrackingService.previewLayer {
                CameraPreviewView(
                    previewLayer: layer,
                    borderColor: .clear,
                    showsBorder: false,
                    cornerRadius: 0
                )
                .opacity(0.5)
            }

            if calibrationService.currentStep == .eyeBox {
                GeometryReader { geometry in
                    EyeTrackingDebugOverlayView(
                        debugState: eyeTrackingService.debugState,
                        viewSize: geometry.size
                    )
                    .opacity(0.8)
                }
            }

            Color.black.opacity(0.35)
                .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}
