//
//  EyeTrackingService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import Combine
import Foundation

class EyeTrackingService: NSObject, ObservableObject {
    static let shared = EyeTrackingService()

    @Published var isEyeTrackingActive = false
    @Published var trackingResult = TrackingResult.empty
    @Published var debugState = EyeTrackingDebugState.empty

    private let cameraManager = CameraSessionManager()
    private let visionPipeline = VisionPipeline()
    private let processor: VisionGazeProcessor
    private var cancellables = Set<AnyCancellable>()

    var previewLayer: AVCaptureVideoPreviewLayer? {
        cameraManager.previewLayer
    }

    var isInFrame: Bool {
        trackingResult.faceDetected
    }

    private override init() {
        let config = TrackingConfig.default
        self.processor = VisionGazeProcessor(config: config)
        super.init()
        cameraManager.delegate = self
        setupSettingsObserver()
    }

    private func setupSettingsObserver() {
        SettingsManager.shared._settingsSubject
            .receive(on: RunLoop.main)
            .sink { [weak self] settings in
                self?.applyStrictness(settings.enforceModeStrictness)
            }
            .store(in: &cancellables)

        applyStrictness(SettingsManager.shared.settings.enforceModeStrictness)
    }

    private func applyStrictness(_ strictness: Double) {
        let config = TrackingConfig(
            horizontalAwayThreshold: 0.08,
            verticalAwayThreshold: 0.12,
            minBaselineSamples: TrackingConfig.default.minBaselineSamples,
            baselineSmoothing: TrackingConfig.default.baselineSmoothing,
            baselineUpdateThreshold: TrackingConfig.default.baselineUpdateThreshold,
            minConfidence: TrackingConfig.default.minConfidence,
            eyeClosedThreshold: TrackingConfig.default.eyeClosedThreshold,
            baselineEnabled: TrackingConfig.default.baselineEnabled,
            defaultCenterHorizontal: TrackingConfig.default.defaultCenterHorizontal,
            defaultCenterVertical: TrackingConfig.default.defaultCenterVertical,
            faceWidthSmoothing: TrackingConfig.default.faceWidthSmoothing,
            faceWidthScaleMin: TrackingConfig.default.faceWidthScaleMin,
            faceWidthScaleMax: 1.4,
            eyeBoundsHorizontalPadding: TrackingConfig.default.eyeBoundsHorizontalPadding,
            eyeBoundsVerticalPaddingUp: TrackingConfig.default.eyeBoundsVerticalPaddingUp,
            eyeBoundsVerticalPaddingDown: TrackingConfig.default.eyeBoundsVerticalPaddingDown
        )

        processor.updateConfig(config)
    }

    func startEyeTracking() async throws {
        print("👁️ startEyeTracking called")
        guard !isEyeTrackingActive else {
            print("⚠️ Eye tracking already active")
            return
        }

        try await cameraManager.start()
        await MainActor.run {
            self.isEyeTrackingActive = true
        }
        print("✓ Eye tracking active")
    }

    func stopEyeTracking() {
        cameraManager.stop()
        Task { @MainActor in
            isEyeTrackingActive = false
            trackingResult = TrackingResult.empty
            debugState = EyeTrackingDebugState.empty
        }
    }
}

extension EyeTrackingService: CameraSessionDelegate {
    @MainActor func cameraSession(
        _ manager: CameraSessionManager,
        didOutput pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    ) {
        let analysis = visionPipeline.analyze(pixelBuffer: pixelBuffer, imageSize: imageSize)
        let observation = processor.process(analysis: analysis)

        trackingResult = TrackingResult(
            faceDetected: observation.faceDetected,
            gazeState: observation.gazeState,
            eyesClosed: observation.eyesClosed,
            confidence: observation.confidence,
            timestamp: Date()
        )
        debugState = observation.debugState
    }
}

// MARK: - Error Handling

enum EyeTrackingError: Error, LocalizedError {
    case noCamera
    case cannotAddInput
    case cannotAddOutput
    case visionRequestFailed

    var errorDescription: String? {
        switch self {
        case .noCamera:
            return "No camera device available."
        case .cannotAddInput:
            return "Cannot add camera input to capture session."
        case .cannotAddOutput:
            return "Cannot add video output to capture session."
        case .visionRequestFailed:
            return "Vision face detection request failed."
        }
    }
}
