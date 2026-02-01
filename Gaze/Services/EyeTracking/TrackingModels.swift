//
//  TrackingModels.swift
//  Gaze
//
//  Created by Mike Freno on 1/31/26.
//

import Foundation

public enum GazeState: String, Sendable {
    case lookingAtScreen
    case lookingAway
    case unknown
}

public struct TrackingResult: Sendable {
    public let faceDetected: Bool
    public let gazeState: GazeState
    public let eyesClosed: Bool
    public let confidence: Double
    public let timestamp: Date

    public static let empty = TrackingResult(
        faceDetected: false,
        gazeState: .unknown,
        eyesClosed: false,
        confidence: 0,
        timestamp: Date()
    )
}

public struct EyeTrackingDebugState: Sendable {
    public let leftEyeRect: CGRect?
    public let rightEyeRect: CGRect?
    public let leftPupil: CGPoint?
    public let rightPupil: CGPoint?
    public let imageSize: CGSize?

    public static let empty = EyeTrackingDebugState(
        leftEyeRect: nil,
        rightEyeRect: nil,
        leftPupil: nil,
        rightPupil: nil,
        imageSize: nil
    )
}

public struct TrackingConfig: Sendable {
    public let horizontalAwayThreshold: Double
    public let verticalAwayThreshold: Double
    public let minBaselineSamples: Int
    public let baselineSmoothing: Double
    public let baselineUpdateThreshold: Double
    public let minConfidence: Double
    public let eyeClosedThreshold: Double
    public let baselineEnabled: Bool
    public let defaultCenterHorizontal: Double
    public let defaultCenterVertical: Double

    public static let `default` = TrackingConfig(
        horizontalAwayThreshold: 0.12,
        verticalAwayThreshold: 0.18,
        minBaselineSamples: 8,
        baselineSmoothing: 0.15,
        baselineUpdateThreshold: 0.08,
        minConfidence: 0.5,
        eyeClosedThreshold: 0.18,
        baselineEnabled: true,
        defaultCenterHorizontal: 0.5,
        defaultCenterVertical: 0.5
    )
}
