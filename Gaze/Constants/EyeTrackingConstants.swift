//
//  EyeTrackingConstants.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Foundation

enum EyeTrackingConstants {
    // MARK: - Logging
    /// Interval between log messages in seconds
    static let logInterval: TimeInterval = 0.5
    
    // MARK: - Eye Closure Detection
    /// Threshold for eye closure (smaller value means eye must be more closed to trigger)
    /// Range: 0.0 to 1.0 (approximate eye opening ratio)
    static let eyeClosedThreshold: CGFloat = 0.02
    
    // MARK: - Face Pose Thresholds
    /// Maximum yaw (left/right head turn) in radians before considering user looking away
    /// 0.20 radians ≈ 11.5 degrees (Tightened from 0.35)
    static let yawThreshold: Double = 0.20
    
    /// Pitch threshold for looking UP (above screen).
    /// Since camera is at top, looking at screen is negative pitch.
    /// Values > 0.1 imply looking straight ahead or up (away from screen).
    static let pitchUpThreshold: Double = 0.1
    
    /// Pitch threshold for looking DOWN (at keyboard/lap).
    /// Values < -0.45 imply looking too far down.
    static let pitchDownThreshold: Double = -0.45
    
    // MARK: - Pupil Tracking Thresholds
    /// Minimum horizontal pupil ratio (0.0 = right edge, 1.0 = left edge)
    /// Values below this are considered looking right (camera view)
    /// Tightened from 0.25 to 0.35
    static let minPupilRatio: Double = 0.35
    
    /// Maximum horizontal pupil ratio
    /// Values above this are considered looking left (camera view)
    /// Tightened from 0.75 to 0.65
    static let maxPupilRatio: Double = 0.65
}
