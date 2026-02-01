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
