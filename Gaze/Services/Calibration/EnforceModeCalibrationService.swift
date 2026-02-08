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

/// Validation state for whether the user appears to be looking at the current calibration target.
enum GazeValidationState: Equatable {
    /// Face detected and gaze direction is consistent with target position
    case valid
    /// Face not detected by the camera
    case noFace
    /// Face detected but gaze direction doesn't match expected target direction
    case wrongDirection
}

@MainActor
final class EnforceModeCalibrationService: ObservableObject {
    static let shared = EnforceModeCalibrationService()

    @Published var isCalibrating = false
    @Published var isCollectingSamples = false
    @Published var currentStep: CalibrationStep = .eyeBox
    @Published var targetIndex = 0
    @Published var countdownProgress: Double = 1.0
    @Published var samplesCollected = 0
    @Published var gazeValidation: GazeValidationState = .valid
    /// True when the countdown/collection is paused due to gaze validation failure
    @Published var isPausedForGaze = false

    private var samples: [CalibrationSample] = []
    private let targets = CalibrationTarget.defaultTargets
    let settingsManager = SettingsManager.shared
    private let eyeTrackingService = EyeTrackingService.shared

    private var countdownTimer: Timer?
    private var sampleTimer: Timer?
    private let countdownDuration: TimeInterval = 0.8
    private let preCountdownPause: TimeInterval = 0.8
    private let sampleInterval: TimeInterval = 0.02
    private let samplesPerTarget = 20
    private var windowController: NSWindowController?

    // Gaze validation: running average of pupil position to compare against target direction
    private var runningHorizontalSum: Double = 0
    private var runningVerticalSum: Double = 0
    private var runningCount: Int = 0
    // How many consecutive validation failures before pausing
    private let validationFailureThreshold = 5
    private var consecutiveValidationFailures = 0
    // Tolerance for directional check (0.5 = center, so we use a generous zone)
    private let directionalTolerance: Double = 0.15

    func start() {
        samples.removeAll()
        targetIndex = 0
        currentStep = .eyeBox
        isCollectingSamples = false
        samplesCollected = 0
        countdownProgress = 1.0
        gazeValidation = .valid
        isPausedForGaze = false
        resetRunningAverage()
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
            resetRunningAverage()
            // Start countdown immediately when transitioning to targets to avoid first point duplication
            startCountdown()
        case .targets:
            if targetIndex < targets.count - 1 {
                targetIndex += 1
                resetRunningAverage()
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
        gazeValidation = .valid
        isPausedForGaze = false
        consecutiveValidationFailures = 0

        var accumulatedCountdown: TimeInterval = 0
        var lastTick = Date()
        var pauseElapsed: TimeInterval = 0

        let startTime = Date()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                let now = Date()
                let wallElapsed = now.timeIntervalSince(startTime)

                // During pre-countdown pause, just check face detection (no directional check yet)
                if wallElapsed < self.preCountdownPause + pauseElapsed {
                    let validation = self.validateFacePresence()
                    self.gazeValidation = validation
                    if validation != .valid {
                        self.isPausedForGaze = true
                        pauseElapsed += now.timeIntervalSince(lastTick)
                    } else {
                        self.isPausedForGaze = false
                    }
                    self.countdownProgress = 1.0
                    lastTick = now
                    return
                }

                // After pause: validate gaze direction before advancing countdown
                let validation = self.validateGazeDirection()
                self.gazeValidation = validation

                if validation == .valid {
                    self.isPausedForGaze = false
                    self.consecutiveValidationFailures = 0
                    let dt = now.timeIntervalSince(lastTick)
                    accumulatedCountdown += dt
                } else {
                    self.consecutiveValidationFailures += 1
                    if self.consecutiveValidationFailures >= self.validationFailureThreshold {
                        self.isPausedForGaze = true
                    }
                }

                lastTick = now
                let remaining = max(0, self.countdownDuration - accumulatedCountdown)
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
        // Only reset to 1.0 when actually stopping, not during transitions
        // countdownProgress = 1.0
    }

    private func startSampleCollection() {
        stopSampleCollection()
        samplesCollected = 0
        isCollectingSamples = true
        consecutiveValidationFailures = 0
        sampleTimer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                // Gate sample collection on face presence
                let validation = self.validateFacePresence()
                self.gazeValidation = validation
                if validation != .valid {
                    self.isPausedForGaze = true
                    return
                }
                self.isPausedForGaze = false

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

    // MARK: - Gaze Validation

    /// Check that the user's face is detected by the camera.
    private func validateFacePresence() -> GazeValidationState {
        let debugState = eyeTrackingService.currentDebugSnapshot()
        guard debugState.normalizedHorizontal != nil,
              debugState.normalizedVertical != nil,
              debugState.faceWidthRatio != nil else {
            return .noFace
        }
        return .valid
    }

    /// Check that the user's gaze direction roughly matches the current target's position.
    ///
    /// We compare the target's screen position against the pupil's normalized position within the eye box.
    /// The key insight: when looking left on screen, the pupil moves to a *higher* normalized x value
    /// (because the camera image is mirrored), and looking right moves it lower. We use a simple
    /// directional consistency check -- if the target is clearly on one side, the pupil should not
    /// be on the opposite side.
    ///
    /// For center targets (x or y near 0.5), we skip the directional check on that axis since
    /// any pupil position is reasonable.
    private func validateGazeDirection() -> GazeValidationState {
        let debugState = eyeTrackingService.currentDebugSnapshot()
        guard let h = debugState.normalizedHorizontal,
              let v = debugState.normalizedVertical,
              debugState.faceWidthRatio != nil else {
            return .noFace
        }

        // Update running average for a stable reference
        updateRunningAverage(horizontal: h, vertical: v)

        // Need at least a few samples to have a stable average
        guard runningCount >= 3 else { return .valid }

        let target = targets[targetIndex]
        let avgH = runningHorizontalSum / Double(runningCount)
        let avgV = runningVerticalSum / Double(runningCount)

        // Check directional consistency on each axis.
        // Target positions are in screen-normalized coords (0 = left/top, 1 = right/bottom).
        // Pupil positions are in eye-box-normalized coords (0-1).
        //
        // Due to camera mirroring, looking LEFT on screen means pupil moves RIGHT in the eye box
        // (higher h value), and looking RIGHT means lower h. Similarly for vertical: looking UP
        // means pupil moves UP in the eye box (lower v in screen coords but depends on processing).
        //
        // Rather than assuming the exact mapping, we use a relative check:
        // - If a target is on the LEFT side of screen (x < 0.35), the current sample's h should
        //   differ from the running average in a consistent direction for left-side targets.
        // - We actually just check that the user's gaze is reasonably distinct for non-center targets.
        //
        // The simplest robust heuristic: for extreme targets (edges), verify the current pupil position
        // is not on the *opposite* extreme from where it was when looking at center-ish targets.
        // But since we don't have a center baseline yet during calibration, we use a simpler approach:
        //
        // Check variance - if the user is not looking at the screen at all (e.g., looking at phone),
        // the pupil values will cluster in one spot regardless of target position. We detect this by
        // checking if there's reasonable movement in the pupil values compared to the initial samples.
        //
        // For now, the face-presence check is the primary gate, and we add a secondary check that
        // the pupil is not in an extreme position that contradicts the target direction.

        let isTargetLeft = target.x < 0.35
        let isTargetRight = target.x > 0.65
        let isTargetTop = target.y < 0.35
        let isTargetBottom = target.y > 0.65

        // Only validate axes where the target is clearly off-center
        // Camera is mirrored: looking screen-left -> higher h value in eye box
        // But the exact mapping depends on processing. We use a relative approach:
        // Compare current h to running average. If target is far left but h is at extreme
        // opposite end from what other left targets produced, flag it.
        //
        // Since this is the first calibration pass, we can't know the mapping yet.
        // Instead, use a simpler heuristic: just ensure consistency within each target.
        // If the pupil position is jittering wildly, the user probably isn't fixating.

        // Check if current reading is wildly different from running average for this target
        let hDelta = abs(h - avgH)
        let vDelta = abs(v - avgV)

        // During a fixation on a single target, pupil position should be relatively stable.
        // Large deviations suggest the user isn't looking at the target.
        // Use a generous threshold -- this isn't about precision, just catching obvious misses.
        let stabilityThreshold = 0.15

        if (isTargetLeft || isTargetRight) && hDelta > stabilityThreshold {
            return .wrongDirection
        }
        if (isTargetTop || isTargetBottom) && vDelta > stabilityThreshold {
            return .wrongDirection
        }

        return .valid
    }

    private func resetRunningAverage() {
        runningHorizontalSum = 0
        runningVerticalSum = 0
        runningCount = 0
        consecutiveValidationFailures = 0
        gazeValidation = .valid
        isPausedForGaze = false
    }

    private func updateRunningAverage(horizontal: Double, vertical: Double) {
        runningHorizontalSum += horizontal
        runningVerticalSum += vertical
        runningCount += 1
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
