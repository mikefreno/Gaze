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
            return "Look to the left"
        case .farRight:
            return "Look as far right as comfortable"
        case .right:
            return "Look to the right"
        case .up:
            return "Look up"
        case .down:
            return "Look down"
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
    let timestamp: Date
    
    init(leftRatio: Double?, rightRatio: Double?) {
        self.leftRatio = leftRatio
        self.rightRatio = rightRatio
        
        // Calculate average from available ratios
        if let left = leftRatio, let right = rightRatio {
            self.averageRatio = (left + right) / 2.0
        } else {
            self.averageRatio = leftRatio ?? rightRatio ?? 0.5
        }
        
        self.timestamp = Date()
    }
}

struct GazeThresholds: Codable {
    let minLeftRatio: Double   // Looking left threshold (e.g., 0.65)
    let maxRightRatio: Double  // Looking right threshold (e.g., 0.35)
    let centerMin: Double      // Center range minimum
    let centerMax: Double      // Center range maximum
    
    var isValid: Bool {
        // Ensure thresholds don't overlap
        return maxRightRatio < centerMin &&
               centerMin < centerMax &&
               centerMax < minLeftRatio
    }
    
    static var defaultThresholds: GazeThresholds {
        GazeThresholds(
            minLeftRatio: 0.65,
            maxRightRatio: 0.35,
            centerMin: 0.40,
            centerMax: 0.60
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
        
        let sum = stepSamples.reduce(0.0) { $0 + $1.averageRatio }
        return sum / Double(stepSamples.count)
    }
    
    func standardDeviation(for step: CalibrationStep) -> Double? {
        let stepSamples = getSamples(for: step)
        guard stepSamples.count > 1, let mean = averageRatio(for: step) else { return nil }
        
        let variance = stepSamples.reduce(0.0) { sum, sample in
            let diff = sample.averageRatio - mean
            return sum + (diff * diff)
        } / Double(stepSamples.count - 1)
        
        return sqrt(variance)
    }
    
    mutating func calculateThresholds() {
        // Need at least center, left, and right samples
        guard let centerMean = averageRatio(for: .center),
              let leftMean = averageRatio(for: .left),
              let rightMean = averageRatio(for: .right) else {
            print("⚠️ Insufficient calibration data to calculate thresholds")
            return
        }
        
        let centerStdDev = standardDeviation(for: .center) ?? 0.05
        
        // Calculate center range (mean ± 0.5 * std_dev)
        let centerMin = max(0.0, centerMean - 0.5 * centerStdDev)
        let centerMax = min(1.0, centerMean + 0.5 * centerStdDev)
        
        // Calculate left threshold (midpoint between center and left extremes)
        let minLeftRatio = centerMax + (leftMean - centerMax) * 0.5
        
        // Calculate right threshold (midpoint between center and right extremes)
        let maxRightRatio = centerMin - (centerMin - rightMean) * 0.5
        
        // Validate and adjust if needed
        var thresholds = GazeThresholds(
            minLeftRatio: min(0.95, max(0.55, minLeftRatio)),
            maxRightRatio: max(0.05, min(0.45, maxRightRatio)),
            centerMin: centerMin,
            centerMax: centerMax
        )
        
        // Ensure no overlap
        if !thresholds.isValid {
            print("⚠️ Computed thresholds overlap, using defaults")
            thresholds = GazeThresholds.defaultThresholds
        }
        
        self.computedThresholds = thresholds
        print("✓ Calibration thresholds calculated:")
        print("  Left: ≥\(String(format: "%.3f", thresholds.minLeftRatio))")
        print("  Center: \(String(format: "%.3f", thresholds.centerMin))-\(String(format: "%.3f", thresholds.centerMax))")
        print("  Right: ≤\(String(format: "%.3f", thresholds.maxRightRatio))")
    }
}
