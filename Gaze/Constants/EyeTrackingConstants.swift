//
//  EyeTrackingConstants.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Foundation

/// Thread-safe configuration holder for eye tracking thresholds.
/// All properties are Sendable constants, safe for use in any concurrency context.
enum EyeTrackingConstants: Sendable {
    // MARK: - Logging
    /// Interval between log messages in seconds
    static let logInterval: TimeInterval = 0.5

    // MARK: - Eye Closure Detection
    /// Threshold for eye closure (smaller value means eye must be more closed to trigger)
    /// Range: 0.0 to 1.0 (approximate eye opening ratio)
    static let eyeClosedThreshold: CGFloat = 0.02
    static let eyeClosedEnabled: Bool = true

    // MARK: - Face Pose Thresholds
    /// Maximum yaw (left/right head turn) in radians before considering user looking away
    /// 0.20 radians ≈ 11.5 degrees (Tightened from 0.35)
    /// NOTE: Vision Framework often provides unreliable yaw/pitch on macOS - disabled by default
    static let yawThreshold: Double = 0.3
    static let yawEnabled: Bool = false

    /// Pitch threshold for looking UP (above screen).
    /// Since camera is at top, looking at screen is negative pitch.
    /// Values > 0.1 imply looking straight ahead or up (away from screen).
    /// NOTE: Vision Framework often doesn't provide pitch data on macOS - disabled by default
    static let pitchUpThreshold: Double = 0.1
    static let pitchUpEnabled: Bool = false

    /// Pitch threshold for looking DOWN (at keyboard/lap).
    /// Values < -0.45 imply looking too far down.
    /// NOTE: Vision Framework often doesn't provide pitch data on macOS - disabled by default
    static let pitchDownThreshold: Double = -0.45
    static let pitchDownEnabled: Bool = false

    // MARK: - Pupil Tracking Thresholds
    /// Minimum horizontal pupil ratio (0.0 = right edge, 1.0 = left edge)
    /// Values below this are considered looking right (camera view)
    /// Tightened to 0.35 based on observed values (typically 0.31-0.47)
    static let minPupilRatio: Double = 0.35
    static let minPupilEnabled: Bool = true

    /// Maximum horizontal pupil ratio
    /// Values above this are considered looking left (camera view)
    /// Tightened to 0.45 based on observed values (typically 0.31-0.47)
    static let maxPupilRatio: Double = 0.45
    static let maxPupilEnabled: Bool = true

    // MARK: - Pixel-Based Gaze Detection Thresholds
    /// Thresholds for pupil-based gaze detection
    /// Based on video test data:
    /// - Looking at screen (center): H ≈ 0.20-0.50
    /// - Looking left (away): H ≈ 0.50+
    /// - Looking right (away): H ≈ 0.20-
    /// Coordinate system: Lower values = right, Higher values = left
    static let pixelGazeMinRatio: Double = 0.20  // Below this = looking right (away)
    static let pixelGazeMaxRatio: Double = 0.50  // Above this = looking left (away)
    static let pixelGazeEnabled: Bool = true
    
    // MARK: - Screen Boundary Detection (New)
    
    /// Forgiveness margin for the "gray area" around the screen edge.
    /// 0.05 means the safe zone is extended by 5% of the range on each side.
    /// If in the gray area, we assume the user is Looking Away (success).
    static let boundaryForgivenessMargin: Double = 0.05
    
    /// Distance sensitivity factor.
    /// 1.0 = Linear scaling (face width 50% smaller -> eye movement expected to be 50% smaller)
    /// > 1.0 = More aggressive scaling
    static let distanceSensitivity: Double = 1.0
    
    /// Default reference face width for distance scaling when uncalibrated.
    /// Measured from test videos at typical laptop distance (~60cm).
    /// Face bounding box width as ratio of image width.
    static let defaultReferenceFaceWidth: Double = 0.4566
    
    /// Minimum confidence required for a valid pupil detection before updating the gaze average.
    /// Helps filter out blinks or noisy frames.
    static let minimumGazeConfidence: Int = 3 // consecutive valid frames
}
