//
//  CalibrationData.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import Foundation

// MARK: - Calibration Models

enum CalibrationStep: String, Codable, CaseIterable {
    case center
    case farLeft
    case left
    case farRight
    case right
    case up
    case down
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var displayName: String {
        switch self {
        case .center: return "Center"
        case .farLeft: return "Far Left"
        case .left: return "Left"
        case .farRight: return "Far Right"
        case .right: return "Right"
        case .up: return "Up"
        case .down: return "Down"
        case .topLeft: return "Top Left"
        case .topRight: return "Top Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomRight: return "Bottom Right"
        }
    }

    var instructionText: String {
        switch self {
        case .center:
            return "Look at the center of the screen"
        case .farLeft:
            return "Look as far left as comfortable"
        case .left:
            return "Look to the left edge of the screen"
        case .farRight:
            return "Look as far right as comfortable"
        case .right:
            return "Look to the right edge of the screen"
        case .up:
            return "Look to the top edge of the screen"
        case .down:
            return "Look to the bottom edge of the screen"
        case .topLeft:
            return "Look to the top left corner"
        case .topRight:
            return "Look to the top right corner"
        case .bottomLeft:
            return "Look to the bottom left corner"
        case .bottomRight:
            return "Look to the bottom right corner"
        }
    }
}

struct GazeSample: Codable {
    let leftRatio: Double?
    let rightRatio: Double?
    let averageRatio: Double
    let leftVerticalRatio: Double?
    let rightVerticalRatio: Double?
    let averageVerticalRatio: Double
    let faceWidthRatio: Double?  // For distance scaling (face width / image width)
    let timestamp: Date

    init(
        leftRatio: Double?,
        rightRatio: Double?,
        leftVerticalRatio: Double? = nil,
        rightVerticalRatio: Double? = nil,
        faceWidthRatio: Double? = nil
    ) {
        self.leftRatio = leftRatio
        self.rightRatio = rightRatio
        self.leftVerticalRatio = leftVerticalRatio
        self.rightVerticalRatio = rightVerticalRatio
        self.faceWidthRatio = faceWidthRatio

        self.averageRatio = GazeSample.average(left: leftRatio, right: rightRatio, fallback: 0.5)
        self.averageVerticalRatio = GazeSample.average(
            left: leftVerticalRatio,
            right: rightVerticalRatio,
            fallback: 0.5
        )

        self.timestamp = Date()
    }

    private static func average(left: Double?, right: Double?, fallback: Double) -> Double {
        switch (left, right) {
        case let (left?, right?):
            return (left + right) / 2.0
        case let (left?, nil):
            return left
        case let (nil, right?):
            return right
        default:
            return fallback
        }
    }
}

struct GazeThresholds: Codable {
    // Horizontal Thresholds
    let minLeftRatio: Double  // Looking left (≥ value)
    let maxRightRatio: Double  // Looking right (≤ value)

    // Vertical Thresholds
    let minUpRatio: Double  // Looking up (≤ value, typically < 0.5)
    let maxDownRatio: Double  // Looking down (≥ value, typically > 0.5)

    // Screen Bounds (Calibration Zone)
    // Defines the rectangle of pupil ratios that correspond to looking AT the screen
    let screenLeftBound: Double
    let screenRightBound: Double
    let screenTopBound: Double
    let screenBottomBound: Double

    // Reference Data for Distance Scaling
    let referenceFaceWidth: Double  // Average face width during calibration

    var isValid: Bool {
        isFiniteValues([
            minLeftRatio, maxRightRatio, minUpRatio, maxDownRatio,
            screenLeftBound, screenRightBound, screenTopBound, screenBottomBound,
        ])
    }

    private func isFiniteValues(_ values: [Double]) -> Bool {
        values.allSatisfy { $0.isFinite }
    }

    /// Default thresholds based on video test data:
    /// - Center (looking at screen): H ≈ 0.29-0.35
    /// - Screen left edge: H ≈ 0.45-0.50
    /// - Looking away left: H ≈ 0.55+
    /// - Screen right edge: H ≈ 0.20-0.25
    /// - Looking away right: H ≈ 0.15-
    /// Coordinate system: Lower H = right, Higher H = left
    static var defaultThresholds: GazeThresholds {
        GazeThresholds(
            minLeftRatio: 0.55,  // Beyond this = looking left (away)
            maxRightRatio: 0.15,  // Below this = looking right (away)
            minUpRatio: 0.30,  // Below this = looking up (away)
            maxDownRatio: 0.60,  // Above this = looking down (away)
            screenLeftBound: 0.50,  // Left edge of screen
            screenRightBound: 0.20,  // Right edge of screen
            screenTopBound: 0.35,  // Top edge of screen
            screenBottomBound: 0.55,  // Bottom edge of screen
            referenceFaceWidth: 0.4566  // Measured from test videos (avg of inner/outer)
        )
    }
}

struct CalibrationData: Codable {
    var samples: [CalibrationStep: [GazeSample]]
    var computedThresholds: GazeThresholds?
    var calibrationDate: Date
    var isComplete: Bool
    private let thresholdCalculator = CalibrationThresholdCalculator()

    enum CodingKeys: String, CodingKey {
        case samples
        case computedThresholds
        case calibrationDate
        case isComplete
    }

    init() {
        self.samples = [:]
        self.computedThresholds = nil
        self.calibrationDate = Date()
        self.isComplete = false
    }

    mutating func addSample(_ sample: GazeSample, for step: CalibrationStep) {
        if samples[step] == nil {
            samples[step] = []
        }
        samples[step]?.append(sample)
    }

    func getSamples(for step: CalibrationStep) -> [GazeSample] {
        return samples[step] ?? []
    }

    func averageRatio(for step: CalibrationStep) -> Double? {
        let stepSamples = getSamples(for: step)
        guard !stepSamples.isEmpty else { return nil }
        return stepSamples.reduce(0.0) { $0 + $1.averageRatio } / Double(stepSamples.count)
    }

    func averageVerticalRatio(for step: CalibrationStep) -> Double? {
        let stepSamples = getSamples(for: step)
        guard !stepSamples.isEmpty else { return nil }
        return stepSamples.reduce(0.0) { $0 + $1.averageVerticalRatio } / Double(stepSamples.count)
    }

    func averageFaceWidth(for step: CalibrationStep) -> Double? {
        let stepSamples = getSamples(for: step)
        let validSamples = stepSamples.compactMap { $0.faceWidthRatio }
        guard !validSamples.isEmpty else { return nil }
        return validSamples.reduce(0.0, +) / Double(validSamples.count)
    }

    mutating func calculateThresholds() {
        self.computedThresholds = thresholdCalculator.calculate(using: self)
        logStepData()
    }

    private func logStepData() {
        print("  Per-step data:")
        for step in CalibrationStep.allCases {
            if let h = averageRatio(for: step) {
                let v = averageVerticalRatio(for: step) ?? -1
                let fw = averageFaceWidth(for: step) ?? -1
                let count = getSamples(for: step).count
                print(
                    "    \(step.rawValue): H=\(String(format: "%.3f", h)), V=\(String(format: "%.3f", v)), FW=\(String(format: "%.3f", fw)), samples=\(count)"
                )
            }
        }
    }
}

/// Thread-safe storage for active calibration thresholds
/// Allows non-isolated code (video processing) to read thresholds without hitting MainActor
class CalibrationState: @unchecked Sendable {
    static let shared = CalibrationState()
    private let queue = DispatchQueue(label: "com.gaze.calibrationState", attributes: .concurrent)
    private var _thresholds: GazeThresholds?
    private var _isComplete: Bool = false

    var thresholds: GazeThresholds? {
        get { queue.sync { _thresholds } }
        set { queue.async(flags: .barrier) { self._thresholds = newValue } }
    }

    var isComplete: Bool {
        get { queue.sync { _isComplete } }
        set { queue.async(flags: .barrier) { self._isComplete = newValue } }
    }

    func reset() {
        setState(thresholds: nil, isComplete: false)
    }

    func setThresholds(_ thresholds: GazeThresholds?) {
        setState(thresholds: thresholds, isComplete: nil)
    }

    func setComplete(_ isComplete: Bool) {
        setState(thresholds: nil, isComplete: isComplete)
    }

    private func setState(thresholds: GazeThresholds?, isComplete: Bool?) {
        queue.async(flags: .barrier) {
            if let thresholds {
                self._thresholds = thresholds
            } else if isComplete == nil {
                self._thresholds = nil
            }
            if let isComplete {
                self._isComplete = isComplete
            }
        }
    }
}
