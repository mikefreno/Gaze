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
    private var eyeTrackingService: EyeTrackingService
    private var timerEngine: TimerEngine?

    private var cancellables = Set<AnyCancellable>()
    private var faceDetectionTimer: Timer?
    private var lastFaceDetectionTime: Date = Date.distantPast
    private let faceDetectionTimeout: TimeInterval = 5.0  // 5 seconds to consider person lost

    private init() {
        self.settingsManager = SettingsManager.shared
        self.eyeTrackingService = EyeTrackingService.shared
        setupObservers()
        initializeEnforceModeState()
    }

    private func setupObservers() {
        eyeTrackingService.$userLookingAtScreen
            .sink { [weak self] lookingAtScreen in
                self?.handleGazeChange(lookingAtScreen: lookingAtScreen)
            }
            .store(in: &cancellables)

        // Observe face detection changes to track person presence
        eyeTrackingService.$faceDetected
            .sink { [weak self] faceDetected in
                self?.handleFaceDetectionChange(faceDetected: faceDetected)
            }
            .store(in: &cancellables)
    }

    private func initializeEnforceModeState() {
        let cameraService = CameraAccessService.shared
        let settingsEnabled = settingsManager.settings.enforcementMode

        // If settings say it's enabled AND camera is authorized, mark as enabled
        if settingsEnabled && cameraService.isCameraAuthorized {
            isEnforceModeEnabled = true
            print("✓ Enforce mode initialized as enabled (camera authorized)")
        } else {
            isEnforceModeEnabled = false
            print("🔒 Enforce mode initialized as disabled")
        }
    }

    func enableEnforceMode() async {
        print("🔒 enableEnforceMode called")
        guard !isEnforceModeEnabled else {
            print("⚠️ Enforce mode already enabled")
            return
        }

        let cameraService = CameraAccessService.shared
        if !cameraService.isCameraAuthorized {
            do {
                print("🔒 Requesting camera permission...")
                try await cameraService.requestCameraAccess()
            } catch {
                print("⚠️ Failed to get camera permission: \(error.localizedDescription)")
                return
            }
        }

        guard cameraService.isCameraAuthorized else {
            print("❌ Camera permission denied")
            return
        }

        isEnforceModeEnabled = true
        print("✓ Enforce mode enabled (camera will activate before lookaway reminders)")
    }

    func disableEnforceMode() {
        guard isEnforceModeEnabled else { return }

        stopCamera()
        isEnforceModeEnabled = false
        userCompliedWithBreak = false
        print("✓ Enforce mode disabled")
    }

    func setTimerEngine(_ engine: TimerEngine) {
        self.timerEngine = engine
    }

    func shouldEnforceBreak(for timerIdentifier: TimerIdentifier) -> Bool {
        guard isEnforceModeEnabled else { return false }
        guard settingsManager.settings.enforcementMode else { return false }

        switch timerIdentifier {
        case .builtIn(let type):
            return type == .lookAway
        case .user:
            return false
        }
    }

    func startCameraForLookawayTimer(secondsRemaining: Int) async {
        guard isEnforceModeEnabled else { return }
        guard !isCameraActive else { return }

        print("👁️ Starting camera for lookaway reminder (T-\(secondsRemaining)s)")

        do {
            try await eyeTrackingService.startEyeTracking()
            isCameraActive = true
            lastFaceDetectionTime = Date()  // Reset grace period
            startFaceDetectionTimer()
            print("✓ Camera active")
        } catch {
            print("⚠️ Failed to start camera: \(error.localizedDescription)")
        }
    }

    func stopCamera() {
        guard isCameraActive else { return }

        print("👁️ Stopping camera")
        eyeTrackingService.stopEyeTracking()
        isCameraActive = false
        userCompliedWithBreak = false

        stopFaceDetectionTimer()
    }

    func checkUserCompliance() {
        guard isCameraActive else {
            userCompliedWithBreak = false
            return
        }

        let lookingAway = !eyeTrackingService.userLookingAtScreen
        userCompliedWithBreak = lookingAway
    }

    private func handleGazeChange(lookingAtScreen: Bool) {
        guard isCameraActive else { return }

        checkUserCompliance()
    }

    private func handleFaceDetectionChange(faceDetected: Bool) {
        // Update the last face detection time only when a face is actively detected
        if faceDetected {
            lastFaceDetectionTime = Date()
        }
    }

    private func startFaceDetectionTimer() {
        stopFaceDetectionTimer()
        // Check every 1 second
        faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
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
        guard isEnforceModeEnabled && isCameraActive else {
            stopFaceDetectionTimer()
            return
        }

        let timeSinceLastDetection = Date().timeIntervalSince(lastFaceDetectionTime)

        // If person has not been detected for too long, temporarily disable enforce mode
        if timeSinceLastDetection > faceDetectionTimeout {
            print(
                "⏰ Person not detected for \(faceDetectionTimeout)s. Temporarily disabling enforce mode."
            )
            disableEnforceMode()
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
        guard !isCameraActive else { return }

        print("🧪 Starting test mode")
        isTestMode = true

        do {
            try await eyeTrackingService.startEyeTracking()
            isCameraActive = true
            lastFaceDetectionTime = Date()  // Reset grace period
            startFaceDetectionTimer()
            print("✓ Test mode camera active")
        } catch {
            print("⚠️ Failed to start test mode camera: \(error.localizedDescription)")
            isTestMode = false
        }
    }

    func stopTestMode() {
        guard isTestMode else { return }

        print("🧪 Stopping test mode")
        stopCamera()
        isTestMode = false
    }
}

