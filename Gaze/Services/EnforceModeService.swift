//
//  EnforceModeService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import Combine
import Foundation

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
