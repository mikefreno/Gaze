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

protocol EnforceCameraControllerDelegate: AnyObject {
    func cameraControllerDidTimeout(_ controller: EnforceCameraController)
    func cameraController(_ controller: EnforceCameraController, didUpdateLookingAtScreen: Bool)
}

final class EnforcePolicyEvaluator {
    private let settingsProvider: any SettingsProviding

    init(settingsProvider: any SettingsProviding) {
        self.settingsProvider = settingsProvider
    }

    var isEnforcementEnabled: Bool {
        settingsProvider.isTimerEnabled(for: .lookAway)
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

    func shouldPreActivateCamera(
        timerIdentifier: TimerIdentifier,
        secondsRemaining: Int
    ) -> Bool {
        guard secondsRemaining <= 3 else { return false }
        return shouldEnforce(timerIdentifier: timerIdentifier)
    }

    func evaluateCompliance(
        isLookingAtScreen: Bool,
        faceDetected: Bool
    ) -> ComplianceResult {
        guard faceDetected else { return .faceNotDetected }
        return isLookingAtScreen ? .notCompliant : .compliant
    }
}

@MainActor
class EnforceCameraController: ObservableObject {
    @Published private(set) var isCameraActive = false
    @Published private(set) var lastFaceDetectionTime: Date = .distantPast

    weak var delegate: EnforceCameraControllerDelegate?

    private let eyeTrackingService: EyeTrackingService
    private var cancellables = Set<AnyCancellable>()
    private var faceDetectionTimer: Timer?
    var faceDetectionTimeout: TimeInterval = 5.0

    init(eyeTrackingService: EyeTrackingService) {
        self.eyeTrackingService = eyeTrackingService
        setupObservers()
    }

    func startCamera() async throws {
        guard !isCameraActive else { return }
        try await eyeTrackingService.startEyeTracking()
        isCameraActive = true
        lastFaceDetectionTime = Date()
        startFaceDetectionTimer()
    }

    func stopCamera() {
        guard isCameraActive else { return }
        eyeTrackingService.stopEyeTracking()
        isCameraActive = false
        stopFaceDetectionTimer()
    }

    func resetFaceDetectionTimer() {
        lastFaceDetectionTime = Date()
    }

    private func setupObservers() {
        eyeTrackingService.$userLookingAtScreen
            .sink { [weak self] lookingAtScreen in
                guard let self else { return }
                self.delegate?.cameraController(self, didUpdateLookingAtScreen: lookingAtScreen)
            }
            .store(in: &cancellables)

        eyeTrackingService.$faceDetected
            .sink { [weak self] faceDetected in
                guard let self else { return }
                if faceDetected {
                    self.lastFaceDetectionTime = Date()
                }
            }
            .store(in: &cancellables)
    }

    private func startFaceDetectionTimer() {
        stopFaceDetectionTimer()

        faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.checkFaceDetectionTimeout()
            }
        }

    }

    private func stopFaceDetectionTimer() {
        faceDetectionTimer?.invalidate()
        faceDetectionTimer = nil
    }

    private func checkFaceDetectionTimeout() {
        guard isCameraActive else {
            stopFaceDetectionTimer()
            return
        }

        let timeSinceLastDetection = Date().timeIntervalSince(lastFaceDetectionTime)
        if timeSinceLastDetection > faceDetectionTimeout {
            delegate?.cameraControllerDidTimeout(self)
        }
    }
}

@MainActor
class EnforceModeService: ObservableObject {
    static let shared = EnforceModeService()

    @Published var isEnforceModeEnabled = false
    @Published var isCameraActive = false
    @Published var userCompliedWithBreak = false
    @Published var isTestMode = false

    private var settingsManager: SettingsManager
    private let policyEvaluator: EnforcePolicyEvaluator
    private let cameraController: EnforceCameraController
    private var timerEngine: TimerEngine?

    private init() {
        self.settingsManager = SettingsManager.shared
        self.policyEvaluator = EnforcePolicyEvaluator(settingsProvider: SettingsManager.shared)
        self.cameraController = EnforceCameraController(eyeTrackingService: EyeTrackingService.shared)
        self.cameraController.delegate = self
        initializeEnforceModeState()
    }

    private func initializeEnforceModeState() {
        let cameraService = CameraAccessService.shared
        let settingsEnabled = policyEvaluator.isEnforcementEnabled

        // If settings say it's enabled AND camera is authorized, mark as enabled
        if settingsEnabled && cameraService.isCameraAuthorized {
            isEnforceModeEnabled = true
            logDebug("✓ Enforce mode initialized as enabled (camera authorized)")
        } else {
            isEnforceModeEnabled = false
            logDebug("🔒 Enforce mode initialized as disabled")
        }
    }

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

    func shouldEnforceBreak(for timerIdentifier: TimerIdentifier) -> Bool {
        guard isEnforceModeEnabled else { return false }
        return policyEvaluator.shouldEnforce(timerIdentifier: timerIdentifier)
    }

    func startCameraForLookawayTimer(secondsRemaining: Int) async {
        guard isEnforceModeEnabled else { return }

        logDebug("👁️ Starting camera for lookaway reminder (T-\(secondsRemaining)s)")

        do {
            try await cameraController.startCamera()
            isCameraActive = cameraController.isCameraActive
            logDebug("✓ Camera active")
        } catch {
            logError("⚠️ Failed to start camera: \(error.localizedDescription)")
        }
    }

    func stopCamera() {
        guard isCameraActive else { return }

        logDebug("👁️ Stopping camera")
        cameraController.stopCamera()
        isCameraActive = false
        userCompliedWithBreak = false
    }

    func checkUserCompliance() {
        guard isCameraActive else {
            userCompliedWithBreak = false
            return
        }
        let compliance = policyEvaluator.evaluateCompliance(
            isLookingAtScreen: EyeTrackingService.shared.userLookingAtScreen,
            faceDetected: EyeTrackingService.shared.faceDetected
        )

        switch compliance {
        case .compliant:
            userCompliedWithBreak = true
        case .notCompliant:
            userCompliedWithBreak = false
        case .faceNotDetected:
            userCompliedWithBreak = false
        }
    }

    func handleReminderDismissed() {
        // Stop camera when reminder is dismissed, but also check if we should disable enforce mode entirely
        // This helps in case a user closes settings window while a reminder is active
        if isCameraActive {
            stopCamera()
        }
    }

    func startTestMode() async {
        guard isEnforceModeEnabled else { return }

        logDebug("🧪 Starting test mode")
        isTestMode = true

        do {
            try await cameraController.startCamera()
            isCameraActive = cameraController.isCameraActive
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

extension EnforceModeService: EnforceCameraControllerDelegate {
    func cameraControllerDidTimeout(_ controller: EnforceCameraController) {
        logDebug(
            "⏰ Person not detected for \(controller.faceDetectionTimeout)s. Temporarily disabling enforce mode."
        )
        disableEnforceMode()
    }

    func cameraController(_ controller: EnforceCameraController, didUpdateLookingAtScreen: Bool) {
        guard isCameraActive else { return }
        checkUserCompliance()
    }
}
