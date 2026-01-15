//
//  EyeTrackingConstants.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Combine
import Foundation

/// Thread-safe configuration holder for eye tracking thresholds.
/// Uses @unchecked Sendable because all access is via the shared singleton
/// and the @Published properties are only mutated from the main thread.
final class EyeTrackingConstants: ObservableObject, @unchecked Sendable {
    static let shared = EyeTrackingConstants()
    
    // MARK: - Logging
    /// Interval between log messages in seconds
    static let logInterval: TimeInterval = 0.5

    // MARK: - Eye Closure Detection
    /// Threshold for eye closure (smaller value means eye must be more closed to trigger)
    /// Range: 0.0 to 1.0 (approximate eye opening ratio)
    @Published var eyeClosedThreshold: CGFloat = 0.02
    @Published var eyeClosedEnabled: Bool = true

    // MARK: - Face Pose Thresholds
    /// Maximum yaw (left/right head turn) in radians before considering user looking away
    /// 0.20 radians ≈ 11.5 degrees (Tightened from 0.35)
    /// NOTE: Vision Framework often provides unreliable yaw/pitch on macOS - disabled by default
    @Published var yawThreshold: Double = 0.3
    @Published var yawEnabled: Bool = false

    /// Pitch threshold for looking UP (above screen).
    /// Since camera is at top, looking at screen is negative pitch.
    /// Values > 0.1 imply looking straight ahead or up (away from screen).
    /// NOTE: Vision Framework often doesn't provide pitch data on macOS - disabled by default
    @Published var pitchUpThreshold: Double = 0.1
    @Published var pitchUpEnabled: Bool = false

    /// Pitch threshold for looking DOWN (at keyboard/lap).
    /// Values < -0.45 imply looking too far down.
    /// NOTE: Vision Framework often doesn't provide pitch data on macOS - disabled by default
    @Published var pitchDownThreshold: Double = -0.45
    @Published var pitchDownEnabled: Bool = false

    // MARK: - Pupil Tracking Thresholds
    /// Minimum horizontal pupil ratio (0.0 = right edge, 1.0 = left edge)
    /// Values below this are considered looking right (camera view)
    /// Tightened to 0.35 based on observed values (typically 0.31-0.47)
    @Published var minPupilRatio: Double = 0.35
    @Published var minPupilEnabled: Bool = true

    /// Maximum horizontal pupil ratio
    /// Values above this are considered looking left (camera view)
    /// Tightened to 0.45 based on observed values (typically 0.31-0.47)
    @Published var maxPupilRatio: Double = 0.45
    @Published var maxPupilEnabled: Bool = true
    
    // MARK: - Pixel-Based Gaze Detection Thresholds
    /// Python GazeTracking thresholds for pixel-based pupil detection
    /// Formula: pupilX / (eyeCenterX * 2 - 10)
    /// Looking right: ratio ≤ 0.35
    /// Looking center: 0.35 < ratio < 0.65
    /// Looking left: ratio ≥ 0.65
    @Published var pixelGazeMinRatio: Double = 0.35  // Looking right threshold
    @Published var pixelGazeMaxRatio: Double = 0.65  // Looking left threshold
    @Published var pixelGazeEnabled: Bool = true
    
    private init() {}
    
    // MARK: - Reset to Defaults
    func resetToDefaults() {
        eyeClosedThreshold = 0.02
        eyeClosedEnabled = true
        yawThreshold = 0.3
        yawEnabled = false  // Disabled by default - Vision Framework unreliable on macOS
        pitchUpThreshold = 0.1
        pitchUpEnabled = false  // Disabled by default - often not available on macOS
        pitchDownThreshold = -0.45
        pitchDownEnabled = false  // Disabled by default - often not available on macOS
        minPupilRatio = 0.35
        minPupilEnabled = true
        maxPupilRatio = 0.45
        maxPupilEnabled = true
    }
}
