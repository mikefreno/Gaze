//
//  CalibrationManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import Combine
import Foundation

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

    private let flowController: CalibrationFlowController
    private var sampleCollector = CalibrationSampleCollector()
    
    // MARK: - Initialization
    
    private init() {
        self.flowController = CalibrationFlowController(
            samplesPerStep: samplesPerStep,
            calibrationSteps: calibrationSteps
        )
        loadCalibration()
        bindFlowController()
    }

    private func bindFlowController() {
        flowController.$isCollectingSamples
            .assign(to: &$isCollectingSamples)
        flowController.$currentStep
            .assign(to: &$currentStep)
        flowController.$currentStepIndex
            .assign(to: &$currentStepIndex)
        flowController.$samplesCollected
            .assign(to: &$samplesCollected)
    }
    
    // MARK: - Calibration Flow
    
    func startCalibration() {
        print("🎯 Starting calibration...")
        isCalibrating = true
        flowController.start()
        calibrationData = CalibrationData()
    }
    
    /// Reset state for a new calibration attempt (clears isComplete flag from previous calibration)
    func resetForNewCalibration() {
        print("🔄 Resetting for new calibration...")
        calibrationData = CalibrationData()
        flowController.start()
    }
    
    func startCollectingSamples() {
        guard isCalibrating else { return }
        print("📊 Started collecting samples for step: \(currentStep?.displayName ?? "unknown")")
        flowController.startCollectingSamples()
    }
    
    func collectSample(
        leftRatio: Double?,
        rightRatio: Double?,
        leftVertical: Double? = nil,
        rightVertical: Double? = nil,
        faceWidthRatio: Double? = nil
    ) {
        guard isCalibrating, isCollectingSamples, let step = currentStep else { return }

        sampleCollector.addSample(
            to: &calibrationData,
            step: step,
            leftRatio: leftRatio,
            rightRatio: rightRatio,
            leftVertical: leftVertical,
            rightVertical: rightVertical,
            faceWidthRatio: faceWidthRatio
        )

        if flowController.markSampleCollected() {
            advanceToNextStep()
        }
    }
    
    private func advanceToNextStep() {
        if flowController.advanceToNextStep() {
            print("📍 Calibration step: \(currentStep?.displayName ?? "unknown")")
        } else {
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
        flowController.stop()
        
        print("✓ Calibration saved and applied")
    }
    
    func cancelCalibration() {
        print("❌ Calibration cancelled")
        isCalibrating = false
        flowController.stop()
        calibrationData = CalibrationData()
        
        CalibrationState.shared.reset()
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
        
        CalibrationState.shared.reset()
        
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
        CalibrationState.shared.setThresholds(thresholds)
        CalibrationState.shared.setComplete(true)
        
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
        flowController.progress
    }
    
    var progressText: String {
        flowController.progressText
    }
}
