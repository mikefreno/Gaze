//
//  CalibrationBridge.swift
//  Gaze
//
//  Thread-safe calibration access for eye tracking.
//

import Foundation

final class CalibrationBridge: @unchecked Sendable {
    nonisolated var thresholds: GazeThresholds? {
        CalibrationState.shared.thresholds
    }

    nonisolated var isComplete: Bool {
        CalibrationState.shared.isComplete
    }

    nonisolated func submitSample(
        leftRatio: Double,
        rightRatio: Double,
        leftVertical: Double?,
        rightVertical: Double?,
        faceWidthRatio: Double
    ) {
        Task { @MainActor in
            CalibrationManager.shared.collectSample(
                leftRatio: leftRatio,
                rightRatio: rightRatio,
                leftVertical: leftVertical,
                rightVertical: rightVertical,
                faceWidthRatio: faceWidthRatio
            )
        }
    }
}
