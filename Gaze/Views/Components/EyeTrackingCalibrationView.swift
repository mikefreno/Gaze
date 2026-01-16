//
//  EyeTrackingCalibrationView.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import SwiftUI

struct EyeTrackingCalibrationView: View {
    @StateObject private var calibrationManager = CalibrationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var countdownValue = 3
    @State private var isCountingDown = false

    var body: some View {
        ZStack {
            // Full-screen black background
            Color.black.ignoresSafeArea()

            if calibrationManager.isCalibrating {
                calibrationContentView
            } else {
                introductionScreenView
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    // MARK: - Introduction Screen

    private var introductionScreenView: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("Eye Tracking Calibration")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .fontWeight(.bold)

            Text("This calibration will help improve eye tracking accuracy.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)

            VStack(alignment: .leading, spacing: 15) {
                InstructionRow(icon: "1.circle.fill", text: "Look at each target on the screen")
                InstructionRow(
                    icon: "2.circle.fill", text: "Keep your head still, only move your eyes")
                InstructionRow(icon: "3.circle.fill", text: "Follow the countdown at each position")
                InstructionRow(icon: "4.circle.fill", text: "Takes about 30-45 seconds")
            }
            .padding(.vertical, 20)

            if calibrationManager.calibrationData.isComplete {
                VStack(spacing: 10) {
                    Text("Last calibration:")
                        .font(.caption)
                        .foregroundStyle(.gray)
                    Text(calibrationManager.getCalibrationSummary())
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                }
                .padding(.vertical)
            }

            HStack(spacing: 20) {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundStyle(.white)
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])

                Button("Start Calibration") {
                    startCalibration()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 20)
        }
        .padding(60)
        .frame(maxWidth: 600)
    }

    // MARK: - Calibration Content

    private var calibrationContentView: some View {
        ZStack {
            // Progress indicator at top
            VStack {
                progressBar
                Spacer()
            }

            // Calibration target
            if let step = calibrationManager.currentStep {
                calibrationTarget(for: step)
            }

            // Skip button at bottom
            VStack {
                Spacer()
                skipButton
            }
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Calibrating...")
                    .foregroundStyle(.white)
                Spacer()
                Text(calibrationManager.progressText)
                    .foregroundStyle(.white.opacity(0.7))
            }

            ProgressView(value: calibrationManager.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }

    // MARK: - Calibration Target

    @ViewBuilder
    private func calibrationTarget(for step: CalibrationStep) -> some View {
        let position = targetPosition(for: step)

        VStack(spacing: 20) {
            // Target circle with countdown
            ZStack {
                // Outer ring (pulsing)
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(isCountingDown ? 1.2 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                        value: isCountingDown)

                // Inner circle
                Circle()
                    .fill(Color.blue)
                    .frame(width: 60, height: 60)

                // Countdown number or checkmark
                if isCountingDown && countdownValue > 0 {
                    Text("\(countdownValue)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                } else if calibrationManager.samplesCollected > 0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            // Instruction text
            Text(step.instructionText)
                .font(.title2)
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
        }
        .position(position)
        .onAppear {
            startStepCountdown()
        }
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button {
            calibrationManager.skipStep()
        } label: {
            Text("Skip this position")
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
        }
        .padding(.bottom, 40)
    }

    // MARK: - Helper Methods

    private func startCalibration() {
        calibrationManager.startCalibration()
    }

    private func startStepCountdown() {
        countdownValue = 3
        isCountingDown = true

        // Countdown 3, 2, 1
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdownValue > 0 {
                countdownValue -= 1
            } else {
                timer.invalidate()
                isCountingDown = false
            }
        }
    }

    private func targetPosition(for step: CalibrationStep) -> CGPoint {
        let screenBounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let width = screenBounds.width
        let height = screenBounds.height

        let centerX = width / 2
        let centerY = height / 2
        let margin: CGFloat = 150

        switch step {
        case .center:
            return CGPoint(x: centerX, y: centerY)
        case .left:
            return CGPoint(x: centerX - width / 4, y: centerY)
        case .right:
            return CGPoint(x: centerX + width / 4, y: centerY)
        case .farLeft:
            return CGPoint(x: margin, y: centerY)
        case .farRight:
            return CGPoint(x: width - margin, y: centerY)
        case .up:
            return CGPoint(x: centerX, y: margin)
        case .down:
            return CGPoint(x: centerX, y: height - margin)
        case .topLeft:
            return CGPoint(x: margin, y: margin)
        case .topRight:
            return CGPoint(x: width - margin, y: margin)
        case .bottomLeft:
            return CGPoint(x: margin, y: height - margin)
        case .bottomRight:
            return CGPoint(x: width - margin, y: height - margin)
        }
    }
}

// MARK: - Instruction Row

struct InstructionRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)

            Text(text)
                .foregroundStyle(.white)
                .font(.body)
        }
    }
}

#Preview {
    EyeTrackingCalibrationView()
}
