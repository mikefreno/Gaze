//
//  CalibratorService.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import Combine
import Foundation
import AppKit
import SwiftUI

final class CalibratorService: ObservableObject {
    static let shared = CalibratorService()

    @Published var isCalibrating = false
    @Published var isCollectingSamples = false
    @Published var currentStep: CalibrationStep?
    @Published var currentStepIndex = 0
    @Published var samplesCollected = 0
    @Published var calibrationData = CalibrationData()

    private let samplesPerStep = 30
    private let userDefaultsKey = "eyeTrackingCalibration"
    private let flowController: CalibrationFlowController
    private var windowController: NSWindowController?

    private init() {
        self.flowController = CalibrationFlowController(
            samplesPerStep: samplesPerStep,
            calibrationSteps: [
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

    func startCalibration() {
        print("🎯 Starting calibration...")
        isCalibrating = true
        flowController.start()
        calibrationData = CalibrationData()
    }

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

        let sample = GazeSample(
            leftRatio: leftRatio,
            rightRatio: rightRatio,
            leftVerticalRatio: leftVertical,
            rightVerticalRatio: rightVertical,
            faceWidthRatio: faceWidthRatio
        )
        calibrationData.addSample(sample, for: step)

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
        guard isCalibrating, let step = currentStep else { return }

        print("⏭️ Skipping calibration step: \(step.displayName)")
        advanceToNextStep()
    }

    func showCalibrationOverlay() {
        guard let screen = NSScreen.main else { return }

        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false

        let overlayView = CalibrationOverlayView {
            self.dismissCalibrationOverlay()
        }
        window.contentView = NSHostingView(rootView: overlayView)

        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("🎯 Calibration overlay window opened")
    }

    func dismissCalibrationOverlay() {
        windowController?.close()
        windowController = nil
        print("🎯 Calibration overlay window closed")
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

    private func applyCalibration() {
        guard let thresholds = calibrationData.computedThresholds else {
            print("⚠️ No thresholds to apply")
            return
        }

        CalibrationState.shared.setThresholds(thresholds)
        CalibrationState.shared.setComplete(true)

        print("✓ Applied calibrated thresholds:")
        print("  Looking left: ≥\(String(format: "%.3f", thresholds.minLeftRatio))")
        print("  Looking right: ≤\(String(format: "%.3f", thresholds.maxRightRatio))")
        print("  Looking up: ≤\(String(format: "%.3f", thresholds.minUpRatio))")
        print("  Looking down: ≥\(String(format: "%.3f", thresholds.maxDownRatio))")
        print("  Screen Bounds: [\(String(format: "%.2f", thresholds.screenRightBound))..\(String(format: "%.2f", thresholds.screenLeftBound))] x [\(String(format: "%.2f", thresholds.screenTopBound))..\(String(format: "%.2f", thresholds.screenBottomBound))]")
    }

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

    var progress: Double {
        flowController.progress
    }

    var progressText: String {
        flowController.progressText
    }

    func submitSampleToBridge(
        leftRatio: Double,
        rightRatio: Double,
        leftVertical: Double? = nil,
        rightVertical: Double? = nil,
        faceWidthRatio: Double = 0
    ) {
        Task { [weak self] in
            self?.collectSample(
                leftRatio: leftRatio,
                rightRatio: rightRatio,
                leftVertical: leftVertical,
                rightVertical: rightVertical,
                faceWidthRatio: faceWidthRatio
            )
        }
    }
}
