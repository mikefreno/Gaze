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
    public let faceWidthRatio: Double?
    public let normalizedHorizontal: Double?
    public let normalizedVertical: Double?

    public static let empty = EyeTrackingDebugState(
        leftEyeRect: nil,
        rightEyeRect: nil,
        leftPupil: nil,
        rightPupil: nil,
        imageSize: nil,
        faceWidthRatio: nil,
        normalizedHorizontal: nil,
        normalizedVertical: nil
    )
}

public struct TrackingConfig: Sendable {
    public init(
        horizontalAwayThreshold: Double,
        verticalAwayThreshold: Double,
        minBaselineSamples: Int,
        baselineSmoothing: Double,
        baselineUpdateThreshold: Double,
        minConfidence: Double,
        eyeClosedThreshold: Double,
        baselineEnabled: Bool,
        defaultCenterHorizontal: Double,
        defaultCenterVertical: Double,
        faceWidthSmoothing: Double,
        faceWidthScaleMin: Double,
        faceWidthScaleMax: Double,
        eyeBoundsHorizontalPadding: Double,
        eyeBoundsVerticalPaddingUp: Double,
        eyeBoundsVerticalPaddingDown: Double
    ) {
        self.horizontalAwayThreshold = horizontalAwayThreshold
        self.verticalAwayThreshold = verticalAwayThreshold
        self.minBaselineSamples = minBaselineSamples
        self.baselineSmoothing = baselineSmoothing
        self.baselineUpdateThreshold = baselineUpdateThreshold
        self.minConfidence = minConfidence
        self.eyeClosedThreshold = eyeClosedThreshold
        self.baselineEnabled = baselineEnabled
        self.defaultCenterHorizontal = defaultCenterHorizontal
        self.defaultCenterVertical = defaultCenterVertical
        self.faceWidthSmoothing = faceWidthSmoothing
        self.faceWidthScaleMin = faceWidthScaleMin
        self.faceWidthScaleMax = faceWidthScaleMax
        self.eyeBoundsHorizontalPadding = eyeBoundsHorizontalPadding
        self.eyeBoundsVerticalPaddingUp = eyeBoundsVerticalPaddingUp
        self.eyeBoundsVerticalPaddingDown = eyeBoundsVerticalPaddingDown
    }

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
    public let faceWidthSmoothing: Double
    public let faceWidthScaleMin: Double
    public let faceWidthScaleMax: Double
    public let eyeBoundsHorizontalPadding: Double
    public let eyeBoundsVerticalPaddingUp: Double
    public let eyeBoundsVerticalPaddingDown: Double

    public static let `default` = TrackingConfig(
        horizontalAwayThreshold: 0.08,
        verticalAwayThreshold: 0.12,
        minBaselineSamples: 8,
        baselineSmoothing: 0.15,
        baselineUpdateThreshold: 0.08,
        minConfidence: 0.5,
        eyeClosedThreshold: 0.18,
        baselineEnabled: true,
        defaultCenterHorizontal: 0.5,
        defaultCenterVertical: 0.5,
        faceWidthSmoothing: 0.12,
        faceWidthScaleMin: 0.85,
        faceWidthScaleMax: 1.4,
        eyeBoundsHorizontalPadding: 0.1,
        eyeBoundsVerticalPaddingUp: 0.9,
        eyeBoundsVerticalPaddingDown: 0.4
    )
}
