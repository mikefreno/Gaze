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

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            introductionScreenView
        }
        .frame(minWidth: 600, minHeight: 500)
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
                    startFullscreenCalibration()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 20)
        }
        .padding(60)
        .frame(maxWidth: 600)
    }

    // MARK: - Actions

    private func startFullscreenCalibration() {
        dismiss()
        
        // Small delay to allow sheet dismissal animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            CalibrationWindowManager.shared.showCalibrationOverlay()
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
