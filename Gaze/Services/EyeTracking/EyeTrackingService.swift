//
//  EyeTrackingService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AppKit
import AVFoundation
import Combine
import Foundation

class EyeTrackingService: NSObject, ObservableObject {
    static let shared = EyeTrackingService()

    @Published var isEyeTrackingActive = false
    @Published var isEyesClosed = false
    @Published var userLookingAtScreen = true
    @Published var faceDetected = false
    @Published var debugLeftPupilRatio: Double?
    @Published var debugRightPupilRatio: Double?
    @Published var debugLeftVerticalRatio: Double?
    @Published var debugRightVerticalRatio: Double?
    @Published var debugYaw: Double?
    @Published var debugPitch: Double?
    @Published var enableDebugLogging: Bool = false {
        didSet {
            debugAdapter.enableDebugLogging = enableDebugLogging
        }
    }
    @Published var debugLeftEyeInput: NSImage?
    @Published var debugRightEyeInput: NSImage?
    @Published var debugLeftEyeProcessed: NSImage?
    @Published var debugRightEyeProcessed: NSImage?
    @Published var debugLeftPupilPosition: PupilPosition?
    @Published var debugRightPupilPosition: PupilPosition?
    @Published var debugLeftEyeSize: CGSize?
    @Published var debugRightEyeSize: CGSize?
    @Published var debugLeftEyeRegion: EyeRegion?
    @Published var debugRightEyeRegion: EyeRegion?
    @Published var debugImageSize: CGSize?

    private let cameraManager = CameraSessionManager()
    private let visionPipeline = VisionPipeline()
    private let debugAdapter = EyeDebugStateAdapter()
    private let gazeDetector: GazeDetector

    var previewLayer: AVCaptureVideoPreviewLayer? {
        cameraManager.previewLayer
    }

    var gazeDirection: GazeDirection {
        guard let leftH = debugLeftPupilRatio,
              let rightH = debugRightPupilRatio,
              let leftV = debugLeftVerticalRatio,
              let rightV = debugRightVerticalRatio else {
            return .center
        }

        let avgHorizontal = (leftH + rightH) / 2.0
        let avgVertical = (leftV + rightV) / 2.0

        return GazeDirection.from(horizontal: avgHorizontal, vertical: avgVertical)
    }

    var isInFrame: Bool {
        faceDetected
    }

    private override init() {
        let configuration = GazeDetector.Configuration(
            thresholds: CalibrationState.shared.thresholds,
            isCalibrationComplete: CalibrationState.shared.isComplete,
            eyeClosedEnabled: EyeTrackingConstants.eyeClosedEnabled,
            eyeClosedThreshold: EyeTrackingConstants.eyeClosedThreshold,
            yawEnabled: EyeTrackingConstants.yawEnabled,
            yawThreshold: EyeTrackingConstants.yawThreshold,
            pitchUpEnabled: EyeTrackingConstants.pitchUpEnabled,
            pitchUpThreshold: EyeTrackingConstants.pitchUpThreshold,
            pitchDownEnabled: EyeTrackingConstants.pitchDownEnabled,
            pitchDownThreshold: EyeTrackingConstants.pitchDownThreshold,
            pixelGazeEnabled: EyeTrackingConstants.pixelGazeEnabled,
            pixelGazeMinRatio: EyeTrackingConstants.pixelGazeMinRatio,
            pixelGazeMaxRatio: EyeTrackingConstants.pixelGazeMaxRatio,
            boundaryForgivenessMargin: EyeTrackingConstants.boundaryForgivenessMargin,
            distanceSensitivity: EyeTrackingConstants.distanceSensitivity,
            defaultReferenceFaceWidth: EyeTrackingConstants.defaultReferenceFaceWidth
        )
        self.gazeDetector = GazeDetector(configuration: configuration)
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
            isEyesClosed = false
            userLookingAtScreen = true
            faceDetected = false
            debugAdapter.clear()
            syncDebugState()
        }
    }

    private func syncDebugState() {
        debugLeftPupilRatio = debugAdapter.leftPupilRatio
        debugRightPupilRatio = debugAdapter.rightPupilRatio
        debugLeftVerticalRatio = debugAdapter.leftVerticalRatio
        debugRightVerticalRatio = debugAdapter.rightVerticalRatio
        debugYaw = debugAdapter.yaw
        debugPitch = debugAdapter.pitch
        debugLeftEyeInput = debugAdapter.leftEyeInput
        debugRightEyeInput = debugAdapter.rightEyeInput
        debugLeftEyeProcessed = debugAdapter.leftEyeProcessed
        debugRightEyeProcessed = debugAdapter.rightEyeProcessed
        debugLeftPupilPosition = debugAdapter.leftPupilPosition
        debugRightPupilPosition = debugAdapter.rightPupilPosition
        debugLeftEyeSize = debugAdapter.leftEyeSize
        debugRightEyeSize = debugAdapter.rightEyeSize
        debugLeftEyeRegion = debugAdapter.leftEyeRegion
        debugRightEyeRegion = debugAdapter.rightEyeRegion
        debugImageSize = debugAdapter.imageSize
    }

    private func updateGazeConfiguration() {
        let configuration = GazeDetector.Configuration(
            thresholds: CalibrationState.shared.thresholds,
            isCalibrationComplete: CalibratorService.shared.isCalibrating || CalibrationState.shared.isComplete,
            eyeClosedEnabled: EyeTrackingConstants.eyeClosedEnabled,
            eyeClosedThreshold: EyeTrackingConstants.eyeClosedThreshold,
            yawEnabled: EyeTrackingConstants.yawEnabled,
            yawThreshold: EyeTrackingConstants.yawThreshold,
            pitchUpEnabled: EyeTrackingConstants.pitchUpEnabled,
            pitchUpThreshold: EyeTrackingConstants.pitchUpThreshold,
            pitchDownEnabled: EyeTrackingConstants.pitchDownEnabled,
            pitchDownThreshold: EyeTrackingConstants.pitchDownThreshold,
            pixelGazeEnabled: EyeTrackingConstants.pixelGazeEnabled,
            pixelGazeMinRatio: EyeTrackingConstants.pixelGazeMinRatio,
            pixelGazeMaxRatio: EyeTrackingConstants.pixelGazeMaxRatio,
            boundaryForgivenessMargin: EyeTrackingConstants.boundaryForgivenessMargin,
            distanceSensitivity: EyeTrackingConstants.distanceSensitivity,
            defaultReferenceFaceWidth: EyeTrackingConstants.defaultReferenceFaceWidth
        )
        gazeDetector.updateConfiguration(configuration)
    }
}

extension EyeTrackingService: CameraSessionDelegate {
    @MainActor func cameraSession(
        _ manager: CameraSessionManager,
        didOutput pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    ) {
        PupilDetector.advanceFrame()

        let analysis = visionPipeline.analyze(pixelBuffer: pixelBuffer, imageSize: imageSize)
        let result = gazeDetector.process(analysis: analysis, pixelBuffer: pixelBuffer)

        if let leftRatio = result.leftPupilRatio,
           let rightRatio = result.rightPupilRatio,
           let faceWidth = result.faceWidthRatio {
            guard CalibratorService.shared.isCalibrating else { return }
            CalibratorService.shared.submitSampleToBridge(
                leftRatio: leftRatio,
                rightRatio: rightRatio,
                leftVertical: result.leftVerticalRatio,
                rightVertical: result.rightVerticalRatio,
                faceWidthRatio: faceWidth
            )
        }

        self.faceDetected = result.faceDetected
        self.isEyesClosed = result.isEyesClosed
        self.userLookingAtScreen = result.userLookingAtScreen
        self.debugAdapter.update(from: result)
        self.debugAdapter.updateEyeImages(from: PupilDetector.self)
        self.syncDebugState()
        self.updateGazeConfiguration()
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

// MARK: - Debug State Adapter

final class EyeDebugStateAdapter {
    var leftPupilRatio: Double?
    var rightPupilRatio: Double?
    var leftVerticalRatio: Double?
    var rightVerticalRatio: Double?
    var yaw: Double?
    var pitch: Double?
    var enableDebugLogging: Bool = false {
        didSet {
            PupilDetector.enableDiagnosticLogging = enableDebugLogging
        }
    }

    var leftEyeInput: NSImage?
    var rightEyeInput: NSImage?
    var leftEyeProcessed: NSImage?
    var rightEyeProcessed: NSImage?
    var leftPupilPosition: PupilPosition?
    var rightPupilPosition: PupilPosition?
    var leftEyeSize: CGSize?
    var rightEyeSize: CGSize?
    var leftEyeRegion: EyeRegion?
    var rightEyeRegion: EyeRegion?
    var imageSize: CGSize?

    var gazeDirection: GazeDirection {
        guard let leftH = leftPupilRatio,
              let rightH = rightPupilRatio,
              let leftV = leftVerticalRatio,
              let rightV = rightVerticalRatio else {
            return .center
        }

        let avgHorizontal = (leftH + rightH) / 2.0
        let avgVertical = (leftV + rightV) / 2.0

        return GazeDirection.from(horizontal: avgHorizontal, vertical: avgVertical)
    }

    func update(from result: EyeTrackingProcessingResult) {
        leftPupilRatio = result.leftPupilRatio
        rightPupilRatio = result.rightPupilRatio
        leftVerticalRatio = result.leftVerticalRatio
        rightVerticalRatio = result.rightVerticalRatio
        yaw = result.yaw
        pitch = result.pitch
    }

    func updateEyeImages(from detector: PupilDetector.Type) {
        if let leftInput = detector.debugLeftEyeInput {
            leftEyeInput = NSImage(cgImage: leftInput, size: NSSize(width: leftInput.width, height: leftInput.height))
        }
        if let rightInput = detector.debugRightEyeInput {
            rightEyeInput = NSImage(cgImage: rightInput, size: NSSize(width: rightInput.width, height: rightInput.height))
        }
        if let leftProcessed = detector.debugLeftEyeProcessed {
            leftEyeProcessed = NSImage(cgImage: leftProcessed, size: NSSize(width: leftProcessed.width, height: leftProcessed.height))
        }
        if let rightProcessed = detector.debugRightEyeProcessed {
            rightEyeProcessed = NSImage(cgImage: rightProcessed, size: NSSize(width: rightProcessed.width, height: rightProcessed.height))
        }
        leftPupilPosition = detector.debugLeftPupilPosition
        rightPupilPosition = detector.debugRightPupilPosition
        leftEyeSize = detector.debugLeftEyeSize
        rightEyeSize = detector.debugRightEyeSize
        leftEyeRegion = detector.debugLeftEyeRegion
        rightEyeRegion = detector.debugRightEyeRegion
        imageSize = detector.debugImageSize
    }

    func clear() {
        leftPupilRatio = nil
        rightPupilRatio = nil
        leftVerticalRatio = nil
        rightVerticalRatio = nil
        yaw = nil
        pitch = nil
        leftEyeInput = nil
        rightEyeInput = nil
        leftEyeProcessed = nil
        rightEyeProcessed = nil
        leftPupilPosition = nil
        rightPupilPosition = nil
        leftEyeSize = nil
        rightEyeSize = nil
        leftEyeRegion = nil
        rightEyeRegion = nil
        imageSize = nil
    }
}
