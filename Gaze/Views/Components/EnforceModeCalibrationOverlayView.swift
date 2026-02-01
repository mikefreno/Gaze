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
            Color.black.opacity(0.85)
                .ignoresSafeArea()

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
        VStack(spacing: 24) {
            Text("Adjust Eye Box")
                .font(.title2)
                .foregroundStyle(.white)

            Text(
                "Use the sliders to fit the boxes around your eyes. When it looks right, continue."
            )
            .font(.callout)
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.8))

            eyePreview

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
            .padding()
            .background(.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

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
        }
        .padding()
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
            }
            .padding()
            .background(Color.black.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .top)

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
    }

    private var completionStep: some View {
        VStack(spacing: 20) {
            Text("Calibration Complete")
                .font(.title2)
                .foregroundStyle(.white)
            Text("You can close this window and start testing.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.8))

            Button("Done") {
                calibrationService.dismissOverlay()
                enforceModeService.stopTestMode()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var eyePreview: some View {
        ZStack {
            if let layer = eyeTrackingService.previewLayer {
                CameraPreviewView(previewLayer: layer, borderColor: NSColor.systemBlue)
                    .frame(height: 240)
            }
            GeometryReader { geometry in
                EyeTrackingDebugOverlayView(
                    debugState: eyeTrackingService.debugState,
                    viewSize: geometry.size
                )
            }
        }
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var targetDot: some View {
        GeometryReader { geometry in
            let target = calibrationService.currentTarget()
            Circle()
                .fill(Color.blue)
                .frame(width: 100, height: 100)
                .position(
                    x: geometry.size.width * target.x,
                    y: geometry.size.height * target.y
                )
                .overlay(
                    Circle()
                        .trim(from: 0, to: CGFloat(calibrationService.countdownProgress))
                        .stroke(Color.blue.opacity(0.8), lineWidth: 6)
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.02), value: calibrationService.countdownProgress)
                )
        }
        .ignoresSafeArea()
    }

    private var countdownRing: some View {
        Circle()
            .trim(from: 0, to: CGFloat(calibrationService.countdownProgress))
            .stroke(Color.blue.opacity(0.8), lineWidth: 6)
            .frame(width: 120, height: 120)
            .rotationEffect(.degrees(-90))
    }
}
