//
//  EnforceModeService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import Combine
import Foundation

enum ComplianceResult {
    case compliant
    case notCompliant
    case faceNotDetected
}

class EnforceModeService: ObservableObject {
    static let shared = EnforceModeService()

    // MARK: - Published State

    @Published var isEnforceModeEnabled = false
    @Published var isCameraActive = false
    @Published var userCompliedWithBreak = false
    @Published var isTestMode = false

    // MARK: - Private Properties

    private var settingsManager: SettingsManager
    private var eyeTrackingService: EyeTrackingService
    private var timerEngine: TimerEngine?
    private var cancellables = Set<AnyCancellable>()
    private var faceDetectionTimer: Timer?
    private var trackingDebugTimer: Timer?
    private var trackingLapStats = TrackingLapStats()
    private var lastLookAwayTime: Date = .distantPast

    // MARK: - Configuration

    private(set) var lastFaceDetectionTime: Date = .distantPast
    var faceDetectionTimeout: TimeInterval = 5.0

    // MARK: - Initialization

    private init() {
        self.settingsManager = SettingsManager.shared
        self.eyeTrackingService = EyeTrackingService.shared
        setupEyeTrackingObservers()
        initializeEnforceModeState()
    }

    private func initializeEnforceModeState() {
        let cameraService = CameraAccessService.shared
        let settingsEnabled = isEnforcementEnabled

        if settingsEnabled && cameraService.isCameraAuthorized {
            isEnforceModeEnabled = true
            logDebug("✓ Enforce mode initialized as enabled (camera authorized)")
        } else {
            isEnforceModeEnabled = false
            logDebug("🔒 Enforce mode initialized as disabled")
        }
    }

    private func setupEyeTrackingObservers() {
        eyeTrackingService.$trackingResult
            .sink { [weak self] _ in
                guard let self, self.isCameraActive else { return }
                self.checkUserCompliance()
            }
            .store(in: &cancellables)

        eyeTrackingService.$trackingResult
            .map { $0.faceDetected }
            .sink { [weak self] faceDetected in
                guard let self else { return }
                if faceDetected {
                    self.lastFaceDetectionTime = Date()
                }
            }
            .store(in: &cancellables)

        settingsManager._settingsSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshEnforceModeState()
            }
            .store(in: &cancellables)

        $isCameraActive
            .removeDuplicates()
            .sink { [weak self] isActive in
                if isActive {
                    self?.startTrackingDebugTimer()
                } else {
                    self?.stopTrackingDebugTimer()
                }
            }
            .store(in: &cancellables)
    }

    private func refreshEnforceModeState() {
        let cameraService = CameraAccessService.shared
        let enabled = isEnforcementEnabled && cameraService.isCameraAuthorized
        if isEnforceModeEnabled != enabled {
            isEnforceModeEnabled = enabled
            logDebug("🔄 Enforce mode state refreshed: \(enabled)")
        }
    }

    // MARK: - Enable/Disable

    func enableEnforceMode() async {
        logDebug("🔒 enableEnforceMode called")
        guard !isEnforceModeEnabled else {
            logError("⚠️ Enforce mode already enabled")
            return
        }

        let cameraService = CameraAccessService.shared
        if !cameraService.isCameraAuthorized {
            do {
                logDebug("🔒 Requesting camera permission...")
                try await cameraService.requestCameraAccess()
            } catch {
                logError("⚠️ Failed to get camera permission: \(error.localizedDescription)")
                return
            }
        }

        guard cameraService.isCameraAuthorized else {
            logError("❌ Camera permission denied")
            return
        }

        isEnforceModeEnabled = true
        logDebug("✓ Enforce mode enabled (camera will activate before lookaway reminders)")
    }

    func disableEnforceMode() {
        guard isEnforceModeEnabled else { return }

        stopCamera()
        isEnforceModeEnabled = false
        userCompliedWithBreak = false
        logDebug("✓ Enforce mode disabled")
    }

    func setTimerEngine(_ engine: TimerEngine) {
        self.timerEngine = engine
    }

    // MARK: - Policy Evaluation

    var isEnforcementEnabled: Bool {
        settingsManager.isTimerEnabled(for: .lookAway)
    }

    func shouldEnforce(timerIdentifier: TimerIdentifier) -> Bool {
        guard isEnforcementEnabled else { return false }

        switch timerIdentifier {
        case .builtIn(let type):
            return type == .lookAway
        case .user:
            return false
        }
    }

    func shouldEnforceBreak(for timerIdentifier: TimerIdentifier) -> Bool {
        guard isEnforceModeEnabled else { return false }
        return shouldEnforce(timerIdentifier: timerIdentifier)
    }

    func shouldPreActivateCamera(
        timerIdentifier: TimerIdentifier,
        secondsRemaining: Int
    ) -> Bool {
        guard secondsRemaining <= 3 else { return false }
        return shouldEnforce(timerIdentifier: timerIdentifier)
    }

    func evaluateCompliance(
        gazeState: GazeState,
        faceDetected: Bool
    ) -> ComplianceResult {
        guard faceDetected else { return .compliant }
        switch gazeState {
        case .lookingAway:
            return .compliant
        case .lookingAtScreen:
            return .notCompliant
        case .unknown:
            return .notCompliant
        }
    }

    // MARK: - Camera Control

    func startCameraForLookawayTimer(secondsRemaining: Int) async {
        guard isEnforceModeEnabled else { return }

        logDebug("👁️ Starting camera for lookaway reminder (T-\(secondsRemaining)s)")

        do {
            try await startCamera()
            logDebug("✓ Camera active")
        } catch {
            logError("⚠️ Failed to start camera: \(error.localizedDescription)")
        }
    }

    private func startCamera() async throws {
        guard !isCameraActive else { return }
        try await eyeTrackingService.startEyeTracking()
        isCameraActive = true
        lastFaceDetectionTime = Date()
        startFaceDetectionTimer()
    }

    func stopCamera() {
        guard isCameraActive else { return }

        logDebug("👁️ Stopping camera")
        eyeTrackingService.stopEyeTracking()
        isCameraActive = false
        stopFaceDetectionTimer()
        stopTrackingDebugTimer()
        userCompliedWithBreak = false
    }

    // MARK: - Compliance Checking

    func checkUserCompliance() {
        guard isCameraActive else {
            userCompliedWithBreak = false
            return
        }
        let compliance = evaluateCompliance(
            gazeState: eyeTrackingService.trackingResult.gazeState,
            faceDetected: eyeTrackingService.trackingResult.faceDetected
        )

        switch compliance {
        case .compliant:
            lastLookAwayTime = Date()
            userCompliedWithBreak = true
        case .notCompliant:
            userCompliedWithBreak = false
        case .faceNotDetected:
            lastLookAwayTime = Date()
            userCompliedWithBreak = true
        }
    }

    func handleReminderDismissed() {
        if isCameraActive {
            stopCamera()
        }
    }

    // MARK: - Face Detection Timer

    private func startFaceDetectionTimer() {
        stopFaceDetectionTimer()

        faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkFaceDetectionTimeout()
        }
    }

    private func stopFaceDetectionTimer() {
        faceDetectionTimer?.invalidate()
        faceDetectionTimer = nil
    }

    private func startTrackingDebugTimer() {
        stopTrackingDebugTimer()
        trackingDebugTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.logTrackingDebugSnapshot()
        }
    }

    private func stopTrackingDebugTimer() {
        trackingDebugTimer?.invalidate()
        trackingDebugTimer = nil
    }

    private func logTrackingDebugSnapshot() {
        guard isCameraActive else { return }

        let debugState = eyeTrackingService.debugState
        let faceWidth = debugState.faceWidthRatio.map { String(format: "%.3f", $0) } ?? "-"
        let horizontal = debugState.normalizedHorizontal.map { String(format: "%.3f", $0) } ?? "-"
        let vertical = debugState.normalizedVertical.map { String(format: "%.3f", $0) } ?? "-"

        trackingLapStats.ingest(
            faceWidth: debugState.faceWidthRatio,
            horizontal: debugState.normalizedHorizontal,
            vertical: debugState.normalizedVertical
        )

        logDebug(
            "📊 Tracking | faceWidth=\(faceWidth) | h=\(horizontal) | v=\(vertical)",
            category: "EyeTracking"
        )
    }

    func logTrackingLap() {
        logDebug("🏁 Tracking Lap", category: "EyeTracking")
        logTrackingDebugSnapshot()

        if let summary = trackingLapStats.summaryString() {
            logDebug("📈 Lap Stats | \(summary)", category: "EyeTracking")
        }
        trackingLapStats.reset()
    }

    private func checkFaceDetectionTimeout() {
        guard isCameraActive else {
            stopFaceDetectionTimer()
            return
        }

        let timeSinceLastDetection = Date().timeIntervalSince(lastFaceDetectionTime)
        if timeSinceLastDetection > faceDetectionTimeout {
            logDebug("⏰ Person not detected for \(faceDetectionTimeout)s. Assuming look away.")
            lastLookAwayTime = Date()
            userCompliedWithBreak = true
            lastFaceDetectionTime = Date()
        }
    }

    func shouldAdvanceLookAwayCountdown() -> Bool {
        guard isEnforceModeEnabled else { return true }
        guard isCameraActive else { return true }

        if !eyeTrackingService.trackingResult.faceDetected {
            lastLookAwayTime = Date()
            return true
        }

        if eyeTrackingService.trackingResult.gazeState == .lookingAway {
            lastLookAwayTime = Date()
            return true
        }

        return Date().timeIntervalSince(lastLookAwayTime) <= 0.25
    }

    // MARK: - Test Mode

    func startTestMode() async {
        guard isEnforceModeEnabled else { return }

        logDebug("🧪 Starting test mode")
        isTestMode = true

        do {
            try await startCamera()
            logDebug("✓ Test mode camera active")
        } catch {
            logError("⚠️ Failed to start test mode camera: \(error.localizedDescription)")
            isTestMode = false
        }
    }

    func stopTestMode() {
        guard isTestMode else { return }

        logDebug("🧪 Stopping test mode")
        stopCamera()
        isTestMode = false
    }
}

private struct TrackingLapStats {
    private var faceWidthValues: [Double] = []
    private var horizontalValues: [Double] = []
    private var verticalValues: [Double] = []

    mutating func ingest(faceWidth: Double?, horizontal: Double?, vertical: Double?) {
        if let faceWidth { faceWidthValues.append(faceWidth) }
        if let horizontal { horizontalValues.append(horizontal) }
        if let vertical { verticalValues.append(vertical) }
    }

    mutating func reset() {
        faceWidthValues.removeAll(keepingCapacity: true)
        horizontalValues.removeAll(keepingCapacity: true)
        verticalValues.removeAll(keepingCapacity: true)
    }

    func summaryString() -> String? {
        guard !faceWidthValues.isEmpty || !horizontalValues.isEmpty || !verticalValues.isEmpty else {
            return nil
        }

        let faceWidth = stats(for: faceWidthValues)
        let horizontal = stats(for: horizontalValues)
        let vertical = stats(for: verticalValues)

        return "faceWidth[\(faceWidth)] h[\(horizontal)] v[\(vertical)]"
    }

    private func stats(for values: [Double]) -> String {
        guard let minValue = values.min(), let maxValue = values.max(), !values.isEmpty else {
            return "-"
        }
        let mean = values.reduce(0, +) / Double(values.count)
        return "min=\(format(minValue)) max=\(format(maxValue)) mean=\(format(mean))"
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
