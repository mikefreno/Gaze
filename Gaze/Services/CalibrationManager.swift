//
//  CalibrationManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import Foundation
import Combine

@MainActor
class CalibrationManager: ObservableObject {
    static let shared = CalibrationManager()
    
    // MARK: - Published Properties
    
    @Published var isCalibrating = false
    @Published var isCollectingSamples = false  // True when actively collecting (after countdown)
    @Published var currentStep: CalibrationStep?
    @Published var currentStepIndex = 0
    @Published var samplesCollected = 0
    @Published var calibrationData = CalibrationData()
    
    // MARK: - Configuration
    
    private let samplesPerStep = 30  // Collect 30 samples per calibration point (~1 second at 30fps)
    private let userDefaultsKey = "eyeTrackingCalibration"
    
    // Calibration sequence (9 steps)
    private let calibrationSteps: [CalibrationStep] = [
        .center,
        .left,
        .right,
        .farLeft,
        .farRight,
        .up,
        .down,
        .topLeft,
        .topRight
    ]
    
    // MARK: - Initialization
    
    private init() {
        loadCalibration()
    }
    
    // MARK: - Calibration Flow
    
    func startCalibration() {
        print("🎯 Starting calibration...")
        isCalibrating = true
        isCollectingSamples = false
        currentStepIndex = 0
        currentStep = calibrationSteps[0]
        samplesCollected = 0
        calibrationData = CalibrationData()
    }
    
    /// Reset state for a new calibration attempt (clears isComplete flag from previous calibration)
    func resetForNewCalibration() {
        print("🔄 Resetting for new calibration...")
        calibrationData = CalibrationData()
    }
    
    func startCollectingSamples() {
        guard isCalibrating, currentStep != nil else { return }
        print("📊 Started collecting samples for step: \(currentStep?.displayName ?? "unknown")")
        isCollectingSamples = true
    }
    
    func collectSample(leftRatio: Double?, rightRatio: Double?, leftVertical: Double? = nil, rightVertical: Double? = nil, faceWidthRatio: Double? = nil) {
        guard isCalibrating, isCollectingSamples, let step = currentStep else { return }
        
        let sample = GazeSample(
            leftRatio: leftRatio,
            rightRatio: rightRatio,
            leftVerticalRatio: leftVertical,
            rightVerticalRatio: rightVertical,
            faceWidthRatio: faceWidthRatio
        )
        calibrationData.addSample(sample, for: step)
        samplesCollected += 1
        
        // Move to next step when enough samples collected
        if samplesCollected >= samplesPerStep {
            advanceToNextStep()
        }
    }
    
    private func advanceToNextStep() {
        isCollectingSamples = false
        currentStepIndex += 1
        
        if currentStepIndex < calibrationSteps.count {
            // Move to next calibration point
            currentStep = calibrationSteps[currentStepIndex]
            samplesCollected = 0
            print("📍 Calibration step: \(currentStep?.displayName ?? "unknown")")
        } else {
            // All steps complete
            finishCalibration()
        }
    }
    
    func skipStep() {
        // Allow skipping optional steps (up, down, diagonals)
        guard isCalibrating, let step = currentStep else { return }
        
        print("⏭️ Skipping calibration step: \(step.displayName)")
        advanceToNextStep()
    }
    
    func finishCalibration() {
        print("✓ Calibration complete, calculating thresholds...")
        
        calibrationData.calculateThresholds()
        calibrationData.isComplete = true
        calibrationData.calibrationDate = Date()
        
        saveCalibration()
        applyCalibration()
        
        isCalibrating = false
        isCollectingSamples = false
        currentStep = nil
        currentStepIndex = 0
        samplesCollected = 0
        
        print("✓ Calibration saved and applied")
    }
    
    func cancelCalibration() {
        print("❌ Calibration cancelled")
        isCalibrating = false
        isCollectingSamples = false
        currentStep = nil
        currentStepIndex = 0
        samplesCollected = 0
        calibrationData = CalibrationData()
        
        // Reset thread-safe state
        CalibrationState.shared.isComplete = false
        CalibrationState.shared.thresholds = nil
    }
    
    // MARK: - Persistence
    
    private func saveCalibration() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(calibrationData)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            print("💾 Calibration data saved to UserDefaults")
        } catch {
            print("❌ Failed to save calibration: \(error)")
        }
    }
    
    func loadCalibration() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            print("ℹ️ No existing calibration found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            calibrationData = try decoder.decode(CalibrationData.self, from: data)
            
            if isCalibrationValid() {
                print("✓ Loaded valid calibration from \(calibrationData.calibrationDate)")
                applyCalibration()
            } else {
                print("⚠️ Calibration expired, needs recalibration")
            }
        } catch {
            print("❌ Failed to load calibration: \(error)")
        }
    }
    
    func clearCalibration() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        calibrationData = CalibrationData()
        
        // Reset thread-safe state
        CalibrationState.shared.isComplete = false
        CalibrationState.shared.thresholds = nil
        
        print("🗑️ Calibration data cleared")
    }
    
    // MARK: - Validation
    
    func isCalibrationValid() -> Bool {
        guard calibrationData.isComplete,
              let thresholds = calibrationData.computedThresholds,
              thresholds.isValid else {
            return false
        }
        return true
    }
    
    func needsRecalibration() -> Bool {
        return !isCalibrationValid()
    }
    
    // MARK: - Apply Calibration
    
    private func applyCalibration() {
        guard let thresholds = calibrationData.computedThresholds else {
            print("⚠️ No thresholds to apply")
            return
        }
        
        // Push to thread-safe state for background processing
        CalibrationState.shared.thresholds = thresholds
        CalibrationState.shared.isComplete = true
        
        print("✓ Applied calibrated thresholds:")
        print("  Looking left: ≥\(String(format: "%.3f", thresholds.minLeftRatio))")
        print("  Looking right: ≤\(String(format: "%.3f", thresholds.maxRightRatio))")
        print("  Looking up: ≤\(String(format: "%.3f", thresholds.minUpRatio))")
        print("  Looking down: ≥\(String(format: "%.3f", thresholds.maxDownRatio))")
        print("  Screen Bounds: [\(String(format: "%.2f", thresholds.screenRightBound))..\(String(format: "%.2f", thresholds.screenLeftBound))] x [\(String(format: "%.2f", thresholds.screenTopBound))..\(String(format: "%.2f", thresholds.screenBottomBound))]")
    }
    
    // MARK: - Statistics
    
    func getCalibrationSummary() -> String {
        guard calibrationData.isComplete else {
            return "No calibration data"
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        var summary = "Calibrated: \(dateFormatter.string(from: calibrationData.calibrationDate))\n"
        
        if let thresholds = calibrationData.computedThresholds {
            summary += "H-Range: \(String(format: "%.3f", thresholds.screenRightBound)) to \(String(format: "%.3f", thresholds.screenLeftBound))\n"
            summary += "V-Range: \(String(format: "%.3f", thresholds.screenTopBound)) to \(String(format: "%.3f", thresholds.screenBottomBound))\n"
            summary += "Ref Face Width: \(String(format: "%.3f", thresholds.referenceFaceWidth))"
        }
        
        return summary
    }
    
    // MARK: - Progress
    
    var progress: Double {
        let totalSteps = calibrationSteps.count
        let completedSteps = currentStepIndex
        let currentProgress = Double(samplesCollected) / Double(samplesPerStep)
        return (Double(completedSteps) + currentProgress) / Double(totalSteps)
    }
    
    var progressText: String {
        "\(currentStepIndex + 1) of \(calibrationSteps.count)"
    }
}
