//
//  CalibrationFlowController.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import Combine
import Foundation

final class CalibrationFlowController: ObservableObject {
    @Published private(set) var currentStep: CalibrationStep?
    @Published private(set) var currentStepIndex = 0
    @Published private(set) var isCollectingSamples = false
    @Published private(set) var samplesCollected = 0

    private let samplesPerStep: Int
    private let calibrationSteps: [CalibrationStep]

    init(samplesPerStep: Int, calibrationSteps: [CalibrationStep]) {
        self.samplesPerStep = samplesPerStep
        self.calibrationSteps = calibrationSteps
        self.currentStep = calibrationSteps.first
    }

    func start() {
        isCollectingSamples = false
        currentStepIndex = 0
        currentStep = calibrationSteps.first
        samplesCollected = 0
    }

    func stop() {
        isCollectingSamples = false
        currentStep = nil
        currentStepIndex = 0
        samplesCollected = 0
    }

    func startCollectingSamples() {
        guard currentStep != nil else { return }
        isCollectingSamples = true
    }

    func resetSamples() {
        isCollectingSamples = false
        samplesCollected = 0
    }

    func markSampleCollected() -> Bool {
        samplesCollected += 1
        return samplesCollected >= samplesPerStep
    }

    func advanceToNextStep() -> Bool {
        isCollectingSamples = false
        currentStepIndex += 1

        guard currentStepIndex < calibrationSteps.count else {
            currentStep = nil
            return false
        }

        currentStep = calibrationSteps[currentStepIndex]
        samplesCollected = 0
        return true
    }

    func skipStep() -> Bool {
        advanceToNextStep()
    }

    var progress: Double {
        let totalSteps = calibrationSteps.count
        guard totalSteps > 0 else { return 0 }
        let currentProgress = Double(samplesCollected) / Double(samplesPerStep)
        return (Double(currentStepIndex) + currentProgress) / Double(totalSteps)
    }

    var progressText: String {
        "\(min(currentStepIndex + 1, calibrationSteps.count)) of \(calibrationSteps.count)"
    }
}
