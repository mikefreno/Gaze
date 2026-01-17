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
        // Just check that we have reasonable values (not NaN or infinite)
        let values = [minLeftRatio, maxRightRatio, minUpRatio, maxDownRatio,
                      screenLeftBound, screenRightBound, screenTopBound, screenBottomBound]
        return values.allSatisfy { $0.isFinite }
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
            minLeftRatio: 0.55,      // Beyond this = looking left (away)
            maxRightRatio: 0.15,     // Below this = looking right (away)
            minUpRatio: 0.30,        // Below this = looking up (away)
            maxDownRatio: 0.60,      // Above this = looking down (away)
            screenLeftBound: 0.50,   // Left edge of screen
            screenRightBound: 0.20,  // Right edge of screen
            screenTopBound: 0.35,    // Top edge of screen
            screenBottomBound: 0.55, // Bottom edge of screen
            referenceFaceWidth: 0.4566  // Measured from test videos (avg of inner/outer)
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
        // Calibration uses actual measured gaze ratios from the user looking at different
        // screen positions. The face width during calibration serves as a reference for
        // distance-based normalization during live tracking.
        //
        // Coordinate system (based on video testing):
        // Horizontal: 0.0 = far right, 1.0 = far left
        // Vertical: 0.0 = top, 1.0 = bottom
        // Center (looking at screen) typically: H ≈ 0.29-0.35
        
        // 1. Get center reference point
        let centerH = averageRatio(for: .center)
        let centerV = averageVerticalRatio(for: .center)
        let centerFaceWidth = averageFaceWidth(for: .center)
        
        guard let cH = centerH else {
            print("⚠️ No center calibration data, using defaults")
            self.computedThresholds = GazeThresholds.defaultThresholds
            return
        }
        
        let cV = centerV ?? 0.45  // Default vertical center
        
        print("📊 Calibration data collected:")
        print("  Center H: \(String(format: "%.3f", cH)), V: \(String(format: "%.3f", cV))")
        
        // 2. Get horizontal screen bounds from left/right calibration points
        // These represent where the user looked when targeting screen edges
        // Use farLeft/farRight for "beyond screen" thresholds, left/right for screen bounds
        
        // Screen bounds (where user looked at screen edges)
        let screenLeftH = averageRatio(for: .left) 
            ?? averageRatio(for: .topLeft) 
            ?? averageRatio(for: .bottomLeft)
        let screenRightH = averageRatio(for: .right) 
            ?? averageRatio(for: .topRight) 
            ?? averageRatio(for: .bottomRight)
        
        // Far bounds (where user looked beyond screen - for "looking away" threshold)
        let farLeftH = averageRatio(for: .farLeft)
        let farRightH = averageRatio(for: .farRight)
        
        // 3. Calculate horizontal thresholds
        // If we have farLeft/farRight, use the midpoint between screen edge and far as threshold
        // Otherwise, extend screen bounds by a margin
        
        let leftBound: Double
        let rightBound: Double
        let lookLeftThreshold: Double
        let lookRightThreshold: Double
        
        if let sLeft = screenLeftH {
            leftBound = sLeft
            // If we have farLeft, threshold is midpoint; otherwise extend by margin
            if let fLeft = farLeftH {
                lookLeftThreshold = (sLeft + fLeft) / 2.0
            } else {
                // Extend beyond screen by ~50% of center-to-edge distance
                let edgeDistance = sLeft - cH
                lookLeftThreshold = sLeft + edgeDistance * 0.5
            }
        } else {
            // No left calibration - estimate based on center
            leftBound = cH + 0.15
            lookLeftThreshold = cH + 0.20
        }
        
        if let sRight = screenRightH {
            rightBound = sRight
            if let fRight = farRightH {
                lookRightThreshold = (sRight + fRight) / 2.0
            } else {
                let edgeDistance = cH - sRight
                lookRightThreshold = sRight - edgeDistance * 0.5
            }
        } else {
            rightBound = cH - 0.15
            lookRightThreshold = cH - 0.20
        }
        
        // 4. Get vertical screen bounds
        let screenTopV = averageVerticalRatio(for: .up) 
            ?? averageVerticalRatio(for: .topLeft) 
            ?? averageVerticalRatio(for: .topRight)
        let screenBottomV = averageVerticalRatio(for: .down) 
            ?? averageVerticalRatio(for: .bottomLeft) 
            ?? averageVerticalRatio(for: .bottomRight)
        
        let topBound: Double
        let bottomBound: Double
        let lookUpThreshold: Double
        let lookDownThreshold: Double
        
        if let sTop = screenTopV {
            topBound = sTop
            let edgeDistance = cV - sTop
            lookUpThreshold = sTop - edgeDistance * 0.5
        } else {
            topBound = cV - 0.10
            lookUpThreshold = cV - 0.15
        }
        
        if let sBottom = screenBottomV {
            bottomBound = sBottom
            let edgeDistance = sBottom - cV
            lookDownThreshold = sBottom + edgeDistance * 0.5
        } else {
            bottomBound = cV + 0.10
            lookDownThreshold = cV + 0.15
        }
        
        // 5. Reference face width for distance normalization
        // Average face width from all calibration steps gives a good reference
        let allFaceWidths = CalibrationStep.allCases.compactMap { averageFaceWidth(for: $0) }
        let refFaceWidth = allFaceWidths.isEmpty ? 0.0 : allFaceWidths.reduce(0.0, +) / Double(allFaceWidths.count)
        
        // 6. Create thresholds
        let thresholds = GazeThresholds(
            minLeftRatio: lookLeftThreshold,
            maxRightRatio: lookRightThreshold,
            minUpRatio: lookUpThreshold,
            maxDownRatio: lookDownThreshold,
            screenLeftBound: leftBound,
            screenRightBound: rightBound,
            screenTopBound: topBound,
            screenBottomBound: bottomBound,
            referenceFaceWidth: refFaceWidth
        )
        
        self.computedThresholds = thresholds
        
        print("✓ Calibration thresholds calculated:")
        print("  Center: H=\(String(format: "%.3f", cH)), V=\(String(format: "%.3f", cV))")
        print("  Screen H-Range: \(String(format: "%.3f", rightBound)) to \(String(format: "%.3f", leftBound))")
        print("  Screen V-Range: \(String(format: "%.3f", topBound)) to \(String(format: "%.3f", bottomBound))")
        print("  Away Thresholds: L≥\(String(format: "%.3f", lookLeftThreshold)), R≤\(String(format: "%.3f", lookRightThreshold))")
        print("  Away Thresholds: U≤\(String(format: "%.3f", lookUpThreshold)), D≥\(String(format: "%.3f", lookDownThreshold))")
        print("  Ref Face Width: \(String(format: "%.3f", refFaceWidth))")
        
        // Log per-step data for debugging
        print("  Per-step data:")
        for step in CalibrationStep.allCases {
            if let h = averageRatio(for: step) {
                let v = averageVerticalRatio(for: step) ?? -1
                let fw = averageFaceWidth(for: step) ?? -1
                let count = getSamples(for: step).count
                print("    \(step.rawValue): H=\(String(format: "%.3f", h)), V=\(String(format: "%.3f", v)), FW=\(String(format: "%.3f", fw)), samples=\(count)")
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
}
