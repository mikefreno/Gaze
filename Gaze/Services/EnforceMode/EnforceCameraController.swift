//
//  EnforceCameraController.swift
//  Gaze
//
//  Manages camera lifecycle for enforce mode sessions.
//

import Combine
import Foundation

protocol EnforceCameraControllerDelegate: AnyObject {
    func cameraControllerDidTimeout(_ controller: EnforceCameraController)
    func cameraController(_ controller: EnforceCameraController, didUpdateLookingAtScreen: Bool)
}

@MainActor
final class EnforceCameraController: ObservableObject {
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
        faceDetectionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
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
