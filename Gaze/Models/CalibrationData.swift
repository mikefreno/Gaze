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
    let faceWidthRatio: Double? // For distance scaling (face width / image width)
    let timestamp: Date
    
    init(leftRatio: Double?, rightRatio: Double?, leftVerticalRatio: Double? = nil, rightVerticalRatio: Double? = nil, faceWidthRatio: Double? = nil) {
        self.leftRatio = leftRatio
        self.rightRatio = rightRatio
        self.leftVerticalRatio = leftVerticalRatio
        self.rightVerticalRatio = rightVerticalRatio
        self.faceWidthRatio = faceWidthRatio
        
        // Calculate average horizontal ratio
        if let left = leftRatio, let right = rightRatio {
            self.averageRatio = (left + right) / 2.0
        } else {
            self.averageRatio = leftRatio ?? rightRatio ?? 0.5
        }
        
        // Calculate average vertical ratio
        if let left = leftVerticalRatio, let right = rightVerticalRatio {
            self.averageVerticalRatio = (left + right) / 2.0
        } else {
            self.averageVerticalRatio = leftVerticalRatio ?? rightVerticalRatio ?? 0.5
        }
        
        self.timestamp = Date()
    }
}

struct GazeThresholds: Codable {
    // Horizontal Thresholds
    let minLeftRatio: Double   // Looking left (≥ value)
    let maxRightRatio: Double  // Looking right (≤ value)
    
    // Vertical Thresholds
    let minUpRatio: Double     // Looking up (≤ value, typically < 0.5)
    let maxDownRatio: Double   // Looking down (≥ value, typically > 0.5)
    
    // Screen Bounds (Calibration Zone)
    // Defines the rectangle of pupil ratios that correspond to looking AT the screen
    let screenLeftBound: Double
    let screenRightBound: Double
    let screenTopBound: Double
    let screenBottomBound: Double
    
    // Reference Data for Distance Scaling
    let referenceFaceWidth: Double // Average face width during calibration
    
    var isValid: Bool {
        // Basic sanity checks
        return maxRightRatio < minLeftRatio &&
               minUpRatio < maxDownRatio &&
               screenRightBound < screenLeftBound && // Assuming lower ratio = right
               screenTopBound < screenBottomBound // Assuming lower ratio = up
    }
    
    static var defaultThresholds: GazeThresholds {
        GazeThresholds(
            minLeftRatio: 0.65,
            maxRightRatio: 0.35,
            minUpRatio: 0.40,
            maxDownRatio: 0.60,
            screenLeftBound: 0.60,
            screenRightBound: 0.40,
            screenTopBound: 0.45,
            screenBottomBound: 0.55,
            referenceFaceWidth: 0.0 // 0.0 means unused/uncalibrated
        )
    }
}

struct CalibrationData: Codable {
    var samples: [CalibrationStep: [GazeSample]]
    var computedThresholds: GazeThresholds?
    var calibrationDate: Date
    var isComplete: Bool
    
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
        // We need Center, Left, Right, Up, Down samples for a full calibration
        // Fallback: If corners (TopLeft, etc.) are available, use them to reinforce bounds
        
        let centerH = averageRatio(for: .center) ?? 0.5
        let centerV = averageVerticalRatio(for: .center) ?? 0.5
        
        // 1. Horizontal Bounds
        // If specific Left/Right steps missing, try corners
        let leftH = averageRatio(for: .left) ?? averageRatio(for: .topLeft) ?? averageRatio(for: .bottomLeft) ?? (centerH + 0.15)
        let rightH = averageRatio(for: .right) ?? averageRatio(for: .topRight) ?? averageRatio(for: .bottomRight) ?? (centerH - 0.15)
        
        // 2. Vertical Bounds
        let upV = averageVerticalRatio(for: .up) ?? averageVerticalRatio(for: .topLeft) ?? averageVerticalRatio(for: .topRight) ?? (centerV - 0.15)
        let downV = averageVerticalRatio(for: .down) ?? averageVerticalRatio(for: .bottomLeft) ?? averageVerticalRatio(for: .bottomRight) ?? (centerV + 0.15)
        
        // 3. Face Width Reference (average of all center samples)
        let refFaceWidth = averageFaceWidth(for: .center) ?? 0.0
        
        // 4. Compute Boundaries with Margin
        // "Screen Bound" is exactly where the user looked.
        // We set thresholds slightly BEYOND that to detect "Looking Away".
        
        // Note: Assuming standard coordinates where:
        // Horizontal: 0.0 (Right) -> 1.0 (Left)
        // Vertical: 0.0 (Up) -> 1.0 (Down)
        
        // Thresholds for "Looking Away"
        // Looking Left = Ratio > Screen Left Edge
        let lookLeftThreshold = leftH + 0.05
        // Looking Right = Ratio < Screen Right Edge
        let lookRightThreshold = rightH - 0.05
        
        // Looking Up = Ratio < Screen Top Edge
        let lookUpThreshold = upV - 0.05
        // Looking Down = Ratio > Screen Bottom Edge
        let lookDownThreshold = downV + 0.05
        
        let thresholds = GazeThresholds(
            minLeftRatio: lookLeftThreshold,
            maxRightRatio: lookRightThreshold,
            minUpRatio: lookUpThreshold,
            maxDownRatio: lookDownThreshold,
            screenLeftBound: leftH,
            screenRightBound: rightH,
            screenTopBound: upV,
            screenBottomBound: downV,
            referenceFaceWidth: refFaceWidth
        )
        
        self.computedThresholds = thresholds
        print("✓ Calibration thresholds calculated:")
        print("  H-Range: \(String(format: "%.3f", rightH)) to \(String(format: "%.3f", leftH))")
        print("  V-Range: \(String(format: "%.3f", upV)) to \(String(format: "%.3f", downV))")
        print("  Ref Face Width: \(String(format: "%.3f", refFaceWidth))")
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
}
