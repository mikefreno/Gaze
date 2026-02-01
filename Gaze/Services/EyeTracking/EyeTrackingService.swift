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
        let settings = SettingsManager.shared.settings
        let widthFactor = settings.enforceModeEyeBoxWidthFactor
        let heightFactor = settings.enforceModeEyeBoxHeightFactor
        let calibration = settings.enforceModeCalibration

        let clamped = min(1, max(0, strictness))
        let scale = 1.6 - (0.8 * clamped)

        let horizontalThreshold: Double
        let verticalThreshold: Double
        let baselineEnabled: Bool
        let centerHorizontal: Double
        let centerVertical: Double

        if let calibration {
            let halfWidth = max(0.01, (calibration.horizontalMax - calibration.horizontalMin) / 2)
            let halfHeight = max(0.01, (calibration.verticalMax - calibration.verticalMin) / 2)
            let marginScale = 0.15
            horizontalThreshold = halfWidth * (1.0 + marginScale) * scale
            verticalThreshold = halfHeight * (1.0 + marginScale) * scale
            baselineEnabled = false
            centerHorizontal = (calibration.horizontalMin + calibration.horizontalMax) / 2
            centerVertical = (calibration.verticalMin + calibration.verticalMax) / 2
        } else {
            horizontalThreshold = TrackingConfig.default.horizontalAwayThreshold * scale
            verticalThreshold = TrackingConfig.default.verticalAwayThreshold * scale
            baselineEnabled = TrackingConfig.default.baselineEnabled
            centerHorizontal = TrackingConfig.default.defaultCenterHorizontal
            centerVertical = TrackingConfig.default.defaultCenterVertical
        }

        let config = TrackingConfig(
            horizontalAwayThreshold: horizontalThreshold,
            verticalAwayThreshold: verticalThreshold,
            minBaselineSamples: TrackingConfig.default.minBaselineSamples,
            baselineSmoothing: TrackingConfig.default.baselineSmoothing,
            baselineUpdateThreshold: TrackingConfig.default.baselineUpdateThreshold,
            minConfidence: TrackingConfig.default.minConfidence,
            eyeClosedThreshold: TrackingConfig.default.eyeClosedThreshold,
            baselineEnabled: baselineEnabled,
            defaultCenterHorizontal: centerHorizontal,
            defaultCenterVertical: centerVertical,
            faceWidthSmoothing: TrackingConfig.default.faceWidthSmoothing,
            faceWidthScaleMin: TrackingConfig.default.faceWidthScaleMin,
            faceWidthScaleMax: 1.4,
            eyeBoundsHorizontalPadding: TrackingConfig.default.eyeBoundsHorizontalPadding,
            eyeBoundsVerticalPaddingUp: TrackingConfig.default.eyeBoundsVerticalPaddingUp,
            eyeBoundsVerticalPaddingDown: TrackingConfig.default.eyeBoundsVerticalPaddingDown,
            eyeBoxWidthFactor: widthFactor,
            eyeBoxHeightFactor: heightFactor
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
