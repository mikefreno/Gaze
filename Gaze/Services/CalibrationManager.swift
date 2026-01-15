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
    @Published var currentStep: CalibrationStep?
    @Published var currentStepIndex = 0
    @Published var samplesCollected = 0
    @Published var calibrationData = CalibrationData()
    
    // MARK: - Configuration
    
    private let samplesPerStep = 20  // Collect 20 samples per calibration point (~1 second at 30fps)
    private let userDefaultsKey = "eyeTrackingCalibration"
    private let calibrationValidityDays = 30
    
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
        currentStepIndex = 0
        currentStep = calibrationSteps[0]
        samplesCollected = 0
        calibrationData = CalibrationData()
    }
    
    func collectSample(leftRatio: Double?, rightRatio: Double?) {
        guard isCalibrating, let step = currentStep else { return }
        
        let sample = GazeSample(leftRatio: leftRatio, rightRatio: rightRatio)
        calibrationData.addSample(sample, for: step)
        samplesCollected += 1
        
        // Move to next step when enough samples collected
        if samplesCollected >= samplesPerStep {
            advanceToNextStep()
        }
    }
    
    private func advanceToNextStep() {
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
        currentStep = nil
        currentStepIndex = 0
        samplesCollected = 0
        
        print("✓ Calibration saved and applied")
    }
    
    func cancelCalibration() {
        print("❌ Calibration cancelled")
        isCalibrating = false
        currentStep = nil
        currentStepIndex = 0
        samplesCollected = 0
        calibrationData = CalibrationData()
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
        print("🗑️ Calibration data cleared")
    }
    
    // MARK: - Validation
    
    func isCalibrationValid() -> Bool {
        guard calibrationData.isComplete,
              let thresholds = calibrationData.computedThresholds,
              thresholds.isValid else {
            return false
        }
        
        // Check if calibration is not too old
        let daysSinceCalibration = Calendar.current.dateComponents(
            [.day],
            from: calibrationData.calibrationDate,
            to: Date()
        ).day ?? 0
        
        return daysSinceCalibration < calibrationValidityDays
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
        
        let constants = EyeTrackingConstants.shared
        constants.pixelGazeMinRatio = thresholds.minLeftRatio
        constants.pixelGazeMaxRatio = thresholds.maxRightRatio
        
        print("✓ Applied calibrated thresholds:")
        print("  Looking left: ≥\(String(format: "%.3f", thresholds.minLeftRatio))")
        print("  Looking right: ≤\(String(format: "%.3f", thresholds.maxRightRatio))")
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
            summary += "Left threshold: \(String(format: "%.3f", thresholds.minLeftRatio))\n"
            summary += "Right threshold: \(String(format: "%.3f", thresholds.maxRightRatio))\n"
            summary += "Center range: \(String(format: "%.3f", thresholds.centerMin)) - \(String(format: "%.3f", thresholds.centerMax))"
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
