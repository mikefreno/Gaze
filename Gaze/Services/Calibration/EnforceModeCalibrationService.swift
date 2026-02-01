//
//  EnforceModeCalibrationService.swift
//  Gaze
//
//  Created by Mike Freno on 2/1/26.
//

import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class EnforceModeCalibrationService: ObservableObject {
    static let shared = EnforceModeCalibrationService()

    @Published var isCalibrating = false
    @Published var isCollectingSamples = false
    @Published var currentStep: CalibrationStep = .eyeBox
    @Published var targetIndex = 0
    @Published var countdownProgress: Double = 1.0
    @Published var samplesCollected = 0

    private var samples: [CalibrationSample] = []
    private let targets = CalibrationTarget.defaultTargets
    let settingsManager = SettingsManager.shared
    private let eyeTrackingService = EyeTrackingService.shared

    private var countdownTimer: Timer?
    private var sampleTimer: Timer?
    private let countdownDuration: TimeInterval = 1.0
    private let preCountdownPause: TimeInterval = 0.5
    private let sampleInterval: TimeInterval = 0.1
    private let samplesPerTarget = 12
    private var windowController: NSWindowController?

    func start() {
        samples.removeAll()
        targetIndex = 0
        currentStep = .eyeBox
        isCollectingSamples = false
        samplesCollected = 0
        countdownProgress = 1.0
        isCalibrating = true
    }

    func presentOverlay() {
        guard windowController == nil else { return }
        guard let screen = NSScreen.main else { return }

        start()

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

        let overlayView = EnforceModeCalibrationOverlayView()
        window.contentView = NSHostingView(rootView: overlayView)

        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismissOverlay() {
        windowController?.close()
        windowController = nil
        isCalibrating = false
    }

    func cancel() {
        stopCountdown()
        stopSampleCollection()
        isCalibrating = false
    }

    func advance() {
        switch currentStep {
        case .eyeBox:
            currentStep = .targets
            startCountdown()
        case .targets:
            if targetIndex < targets.count - 1 {
                targetIndex += 1
                startCountdown()
            } else {
                finish()
            }
        case .complete:
            isCalibrating = false
        }
    }

    func recordSample() {
        let debugState = eyeTrackingService.currentDebugSnapshot()
        guard let h = debugState.normalizedHorizontal,
              let v = debugState.normalizedVertical,
              let faceWidth = debugState.faceWidthRatio else {
            return
        }

        let target = targets[targetIndex]
        samples.append(
            CalibrationSample(
                target: target,
                horizontal: h,
                vertical: v,
                faceWidthRatio: faceWidth
            )
        )
    }

    func currentTarget() -> CalibrationTarget {
        targets[targetIndex]
    }

    private func startCountdown() {
        stopCountdown()
        stopSampleCollection()

        countdownProgress = 1.0
        let startTime = Date()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(startTime)
                let countdownElapsed = max(0, elapsed - self.preCountdownPause)
                if elapsed < self.preCountdownPause {
                    self.countdownProgress = 1.0
                    return
                }
                let remaining = max(0, self.countdownDuration - countdownElapsed)
                self.countdownProgress = remaining / self.countdownDuration
                if remaining <= 0 {
                    self.stopCountdown()
                    self.startSampleCollection()
                }
            }
        }
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownProgress = 1.0
    }

    private func startSampleCollection() {
        stopSampleCollection()
        samplesCollected = 0
        isCollectingSamples = true
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.recordSample()
                self.samplesCollected += 1
                if self.samplesCollected >= self.samplesPerTarget {
                    self.stopSampleCollection()
                    self.advance()
                }
            }
        }
    }

    private func stopSampleCollection() {
        sampleTimer?.invalidate()
        sampleTimer = nil
        isCollectingSamples = false
    }

    private func finish() {
        stopCountdown()
        stopSampleCollection()
        guard let calibration = CalibrationSample.makeCalibration(samples: samples) else {
            currentStep = .complete
            return
        }

        settingsManager.settings.enforceModeCalibration = calibration
        currentStep = .complete
    }

    var progress: Double {
        guard !targets.isEmpty else { return 0 }
        return Double(targetIndex) / Double(targets.count)
    }

    var progressText: String {
        "\(min(targetIndex + 1, targets.count))/\(targets.count)"
    }
}

enum CalibrationStep: String {
    case eyeBox
    case targets
    case complete
}

struct CalibrationTarget: Identifiable, Sendable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let label: String

    static let defaultTargets: [CalibrationTarget] = [
        CalibrationTarget(x: 0.1, y: 0.1, label: "Top Left"),
        CalibrationTarget(x: 0.5, y: 0.1, label: "Top"),
        CalibrationTarget(x: 0.9, y: 0.1, label: "Top Right"),
        CalibrationTarget(x: 0.9, y: 0.5, label: "Right"),
        CalibrationTarget(x: 0.9, y: 0.9, label: "Bottom Right"),
        CalibrationTarget(x: 0.5, y: 0.9, label: "Bottom"),
        CalibrationTarget(x: 0.1, y: 0.9, label: "Bottom Left"),
        CalibrationTarget(x: 0.1, y: 0.5, label: "Left"),
        CalibrationTarget(x: 0.5, y: 0.5, label: "Center")
    ]
}

private struct CalibrationSample: Sendable {
    let target: CalibrationTarget
    let horizontal: Double
    let vertical: Double
    let faceWidthRatio: Double

    static func makeCalibration(samples: [CalibrationSample]) -> EnforceModeCalibration? {
        guard !samples.isEmpty else { return nil }

        let horizontalValues = samples.map { $0.horizontal }
        let verticalValues = samples.map { $0.vertical }
        let faceWidths = samples.map { $0.faceWidthRatio }

        guard let minH = horizontalValues.min(),
              let maxH = horizontalValues.max(),
              let minV = verticalValues.min(),
              let maxV = verticalValues.max() else {
            return nil
        }

        let faceWidthMean = faceWidths.reduce(0, +) / Double(faceWidths.count)

        return EnforceModeCalibration(
            createdAt: Date(),
            eyeBoxWidthFactor: SettingsManager.shared.settings.enforceModeEyeBoxWidthFactor,
            eyeBoxHeightFactor: SettingsManager.shared.settings.enforceModeEyeBoxHeightFactor,
            faceWidthRatio: faceWidthMean,
            horizontalMin: minH,
            horizontalMax: maxH,
            verticalMin: minV,
            verticalMax: maxV
        )
    }
}
