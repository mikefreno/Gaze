//
//  EyeTrackingService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import Combine
import Vision
import simd

@MainActor
class EyeTrackingService: NSObject, ObservableObject {
    static let shared = EyeTrackingService()

    @Published var isEyeTrackingActive = false
    @Published var isEyesClosed = false
    @Published var userLookingAtScreen = true
    @Published var faceDetected = false

    // Debug properties for UI display
    @Published var debugLeftPupilRatio: Double?
    @Published var debugRightPupilRatio: Double?
    @Published var debugYaw: Double?
    @Published var debugPitch: Double?
    @Published var enableDebugLogging: Bool = false

    // Throttle for debug logging
    private var lastDebugLogTime: Date = .distantPast

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoDataOutputQueue = DispatchQueue(
        label: "com.gaze.videoDataOutput", qos: .userInitiated)
    private var _previewLayer: AVCaptureVideoPreviewLayer?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else {
            _previewLayer = nil
            return nil
        }

        // Reuse existing layer if session hasn't changed
        if let existing = _previewLayer, existing.session === session {
            return existing
        }

        // Create new layer only when session changes
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        _previewLayer = layer
        return layer
    }

    private override init() {
        super.init()
    }

    // MARK: - Processing Result

    /// Result struct for off-main-thread processing
    private struct ProcessingResult: Sendable {
        var faceDetected: Bool = false
        var isEyesClosed: Bool = false
        var userLookingAtScreen: Bool = true
        var debugLeftPupilRatio: Double?
        var debugRightPupilRatio: Double?
        var debugYaw: Double?
        var debugPitch: Double?
        
        nonisolated init(
            faceDetected: Bool = false,
            isEyesClosed: Bool = false,
            userLookingAtScreen: Bool = true,
            debugLeftPupilRatio: Double? = nil,
            debugRightPupilRatio: Double? = nil,
            debugYaw: Double? = nil,
            debugPitch: Double? = nil
        ) {
            self.faceDetected = faceDetected
            self.isEyesClosed = isEyesClosed
            self.userLookingAtScreen = userLookingAtScreen
            self.debugLeftPupilRatio = debugLeftPupilRatio
            self.debugRightPupilRatio = debugRightPupilRatio
            self.debugYaw = debugYaw
            self.debugPitch = debugPitch
        }
    }

    func startEyeTracking() async throws {
        print("👁️ startEyeTracking called")
        guard !isEyeTrackingActive else {
            print("⚠️ Eye tracking already active")
            return
        }

        let cameraService = CameraAccessService.shared
        print("👁️ Camera authorized: \(cameraService.isCameraAuthorized)")

        if !cameraService.isCameraAuthorized {
            print("👁️ Requesting camera access...")
            try await cameraService.requestCameraAccess()
        }

        guard cameraService.isCameraAuthorized else {
            print("❌ Camera access denied")
            throw CameraAccessError.accessDenied
        }

        print("👁️ Setting up capture session...")
        try await setupCaptureSession()

        print("👁️ Starting capture session...")
        captureSession?.startRunning()
        isEyeTrackingActive = true
        print("✓ Eye tracking active")
    }

    func stopEyeTracking() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        _previewLayer = nil
        isEyeTrackingActive = false
        isEyesClosed = false
        userLookingAtScreen = true
        faceDetected = false
    }

    private func setupCaptureSession() async throws {
        let session = AVCaptureSession()
        session.sessionPreset = .vga640x480

        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw EyeTrackingError.noCamera
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard session.canAddInput(videoInput) else {
            throw EyeTrackingError.cannotAddInput
        }
        session.addInput(videoInput)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        output.alwaysDiscardsLateVideoFrames = true

        guard session.canAddOutput(output) else {
            throw EyeTrackingError.cannotAddOutput
        }
        session.addOutput(output)

        self.captureSession = session
        self.videoOutput = output
    }

    private func processFaceObservations(
        _ observations: [VNFaceObservation]?, imageSize: CGSize, pixelBuffer: CVPixelBuffer? = nil
    ) {
        guard let observations = observations, !observations.isEmpty else {
            faceDetected = false
            userLookingAtScreen = false
            return
        }

        faceDetected = true
        let face = observations.first!

        if enableDebugLogging {
            print("👁️ Face observation - boundingBox: \(face.boundingBox)")
            print(
                "👁️ Yaw: \(face.yaw?.doubleValue ?? 999), Pitch: \(face.pitch?.doubleValue ?? 999), Roll: \(face.roll?.doubleValue ?? 999)"
            )
        }

        guard let landmarks = face.landmarks else {
            if enableDebugLogging {
                print("👁️ No landmarks available")
            }
            return
        }

        if enableDebugLogging {
            print(
                "👁️ Landmarks - leftEye: \(landmarks.leftEye != nil), rightEye: \(landmarks.rightEye != nil), leftPupil: \(landmarks.leftPupil != nil), rightPupil: \(landmarks.rightPupil != nil)"
            )
        }

        // Check eye closure
        if let leftEye = landmarks.leftEye,
            let rightEye = landmarks.rightEye
        {
            let eyesClosed = detectEyesClosed(
                leftEye: leftEye, rightEye: rightEye, shouldLog: false)
            self.isEyesClosed = eyesClosed
        }

        // Check gaze direction
        let lookingAway = detectLookingAway(
            face: face,
            landmarks: landmarks,
            imageSize: imageSize,
            pixelBuffer: pixelBuffer,
            shouldLog: enableDebugLogging
        )
        userLookingAtScreen = !lookingAway
    }

    /// Non-isolated synchronous version for off-main-thread processing
    /// Returns a result struct instead of updating @Published properties directly
    nonisolated private func processFaceObservationsSync(
        _ observations: [VNFaceObservation]?,
        imageSize: CGSize,
        pixelBuffer: CVPixelBuffer? = nil
    ) -> ProcessingResult {
        var result = ProcessingResult()

        guard let observations = observations, !observations.isEmpty else {
            result.faceDetected = false
            result.userLookingAtScreen = false
            return result
        }

        result.faceDetected = true
        let face = observations.first!

        guard let landmarks = face.landmarks else {
            return result
        }

        // Check eye closure
        if let leftEye = landmarks.leftEye,
            let rightEye = landmarks.rightEye
        {
            result.isEyesClosed = detectEyesClosedSync(
                leftEye: leftEye, rightEye: rightEye)
        }

        // Check gaze direction
        let gazeResult = detectLookingAwaySync(
            face: face,
            landmarks: landmarks,
            imageSize: imageSize,
            pixelBuffer: pixelBuffer
        )

        result.userLookingAtScreen = !gazeResult.lookingAway
        result.debugLeftPupilRatio = gazeResult.leftPupilRatio
        result.debugRightPupilRatio = gazeResult.rightPupilRatio
        result.debugYaw = gazeResult.yaw
        result.debugPitch = gazeResult.pitch

        return result
    }

    /// Non-isolated eye closure detection
    nonisolated private func detectEyesClosedSync(
        leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D
    ) -> Bool {
        guard EyeTrackingConstants.eyeClosedEnabled else {
            return false
        }

        guard leftEye.pointCount >= 2, rightEye.pointCount >= 2 else {
            return false
        }

        let leftEyeHeight = calculateEyeHeightSync(leftEye)
        let rightEyeHeight = calculateEyeHeightSync(rightEye)

        let closedThreshold = EyeTrackingConstants.eyeClosedThreshold

        return leftEyeHeight < closedThreshold && rightEyeHeight < closedThreshold
    }

    nonisolated private func calculateEyeHeightSync(_ eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let points = eye.normalizedPoints
        guard points.count >= 2 else { return 0 }

        let yValues = points.map { $0.y }
        let maxY = yValues.max() ?? 0
        let minY = yValues.min() ?? 0

        return abs(maxY - minY)
    }

    /// Non-isolated gaze detection result
    private struct GazeResult: Sendable {
        var lookingAway: Bool = false
        var leftPupilRatio: Double?
        var rightPupilRatio: Double?
        var yaw: Double?
        var pitch: Double?
        
        nonisolated init(
            lookingAway: Bool = false,
            leftPupilRatio: Double? = nil,
            rightPupilRatio: Double? = nil,
            yaw: Double? = nil,
            pitch: Double? = nil
        ) {
            self.lookingAway = lookingAway
            self.leftPupilRatio = leftPupilRatio
            self.rightPupilRatio = rightPupilRatio
            self.yaw = yaw
            self.pitch = pitch
        }
    }

    /// Non-isolated gaze direction detection
    nonisolated private func detectLookingAwaySync(
        face: VNFaceObservation,
        landmarks: VNFaceLandmarks2D,
        imageSize: CGSize,
        pixelBuffer: CVPixelBuffer?
    ) -> GazeResult {
        var result = GazeResult()

// 1. Face Pose Check (Yaw & Pitch)
         let yaw = face.yaw?.doubleValue ?? 0.0
         let pitch = face.pitch?.doubleValue ?? 0.0

         result.yaw = yaw
         result.pitch = pitch

         var poseLookingAway = false

         if face.pitch != nil {
             if EyeTrackingConstants.yawEnabled {
                 let yawThreshold = EyeTrackingConstants.yawThreshold
                 if abs(yaw) > yawThreshold {
                     poseLookingAway = true
                 }
             }

             if !poseLookingAway {
                 var pitchLookingAway = false

                 if EyeTrackingConstants.pitchUpEnabled && pitch > EyeTrackingConstants.pitchUpThreshold {
                     pitchLookingAway = true
                 }

                 if EyeTrackingConstants.pitchDownEnabled && pitch < EyeTrackingConstants.pitchDownThreshold {
                     pitchLookingAway = true
                 }

                 poseLookingAway = pitchLookingAway
             }
         }

         // 2. Eye Gaze Check (Pixel-Based Pupil Detection)
         var eyesLookingAway = false

         if let pixelBuffer = pixelBuffer,
             let leftEye = landmarks.leftEye,
             let rightEye = landmarks.rightEye,
             EyeTrackingConstants.pixelGazeEnabled
         {
            var leftGazeRatio: Double? = nil
            var rightGazeRatio: Double? = nil

            // Detect left pupil (side = 0)
            if let leftResult = PupilDetector.detectPupil(
                in: pixelBuffer,
                eyeLandmarks: leftEye,
                faceBoundingBox: face.boundingBox,
                imageSize: imageSize,
                side: 0
            ) {
                leftGazeRatio = calculateGazeRatioSync(
                    pupilPosition: leftResult.pupilPosition,
                    eyeRegion: leftResult.eyeRegion
                )
            }

            // Detect right pupil (side = 1)
            if let rightResult = PupilDetector.detectPupil(
                in: pixelBuffer,
                eyeLandmarks: rightEye,
                faceBoundingBox: face.boundingBox,
                imageSize: imageSize,
                side: 1
            ) {
                rightGazeRatio = calculateGazeRatioSync(
                    pupilPosition: rightResult.pupilPosition,
                    eyeRegion: rightResult.eyeRegion
                )
            }

            result.leftPupilRatio = leftGazeRatio
            result.rightPupilRatio = rightGazeRatio

            // Connect to CalibrationManager on main thread
            if let leftRatio = leftGazeRatio,
                let rightRatio = rightGazeRatio
            {
                Task { @MainActor in
                    if CalibrationManager.shared.isCalibrating {
                        CalibrationManager.shared.collectSample(
                            leftRatio: leftRatio,
                            rightRatio: rightRatio
                        )
                    }
                }

                let avgRatio = (leftRatio + rightRatio) / 2.0
                let lookingRight = avgRatio <= EyeTrackingConstants.pixelGazeMinRatio
                let lookingLeft = avgRatio >= EyeTrackingConstants.pixelGazeMaxRatio
                eyesLookingAway = lookingRight || lookingLeft
            }
        }

        result.lookingAway = poseLookingAway || eyesLookingAway
        return result
    }

    /// Non-isolated gaze ratio calculation
    nonisolated private func calculateGazeRatioSync(
        pupilPosition: PupilPosition, eyeRegion: EyeRegion
    ) -> Double {
        let pupilX = Double(pupilPosition.x)
        let eyeCenterX = Double(eyeRegion.center.x)

        let denominator = (eyeCenterX * 2.0 - 10.0)

        guard denominator > 0 else {
            let eyeLeft = Double(eyeRegion.frame.minX)
            let eyeRight = Double(eyeRegion.frame.maxX)
            let eyeWidth = eyeRight - eyeLeft
            guard eyeWidth > 0 else { return 0.5 }
            return (pupilX - eyeLeft) / eyeWidth
        }

        let ratio = pupilX / denominator
        return max(0.0, min(1.0, ratio))
    }

    private func detectEyesClosed(
        leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D, shouldLog: Bool
    ) -> Bool {
        // If eye closure detection is disabled, always return false (eyes not closed)
        guard EyeTrackingConstants.eyeClosedEnabled else {
            return false
        }

        guard leftEye.pointCount >= 2, rightEye.pointCount >= 2 else {
            return false
        }

        let leftEyeHeight = calculateEyeHeight(leftEye, shouldLog: shouldLog)
        let rightEyeHeight = calculateEyeHeight(rightEye, shouldLog: shouldLog)

        let closedThreshold = EyeTrackingConstants.eyeClosedThreshold

        let isClosed = leftEyeHeight < closedThreshold && rightEyeHeight < closedThreshold

        return isClosed
    }

    private func calculateEyeHeight(_ eye: VNFaceLandmarkRegion2D, shouldLog: Bool) -> CGFloat {
        let points = eye.normalizedPoints
        guard points.count >= 2 else { return 0 }

        let yValues = points.map { $0.y }
        let maxY = yValues.max() ?? 0
        let minY = yValues.min() ?? 0

        let height = abs(maxY - minY)

        return height
    }

    private func detectLookingAway(
        face: VNFaceObservation, landmarks: VNFaceLandmarks2D, imageSize: CGSize,
        pixelBuffer: CVPixelBuffer?, shouldLog: Bool
    ) -> Bool {
        // 1. Face Pose Check (Yaw & Pitch)
        let yaw = face.yaw?.doubleValue ?? 0.0
        let pitch = face.pitch?.doubleValue ?? 0.0
        let roll = face.roll?.doubleValue ?? 0.0

        // Debug logging
        if shouldLog {
            print("👁️ Face Pose - Yaw: \(yaw), Pitch: \(pitch), Roll: \(roll)")
            print(
                "👁️ Face available data - hasYaw: \(face.yaw != nil), hasPitch: \(face.pitch != nil), hasRoll: \(face.roll != nil)"
            )
        }

        // Update debug values
        Task { @MainActor in
            debugYaw = yaw
            debugPitch = pitch
        }

        var poseLookingAway = false

        // Only use yaw/pitch if they're actually available and enabled
        // Note: Vision Framework on macOS often doesn't provide reliable pitch data
        if face.pitch != nil {
            // Check yaw if enabled
            if EyeTrackingConstants.yawEnabled {
                let yawThreshold = EyeTrackingConstants.yawThreshold
                if abs(yaw) > yawThreshold {
                    poseLookingAway = true
                }
            }

            // Check pitch if either threshold is enabled
            if !poseLookingAway {
                var pitchLookingAway = false

                if EyeTrackingConstants.pitchUpEnabled
                    && pitch > EyeTrackingConstants.pitchUpThreshold
                {
                    pitchLookingAway = true
                }

                if EyeTrackingConstants.pitchDownEnabled
                    && pitch < EyeTrackingConstants.pitchDownThreshold
                {
                    pitchLookingAway = true
                }

                poseLookingAway = pitchLookingAway
            }
        }

        // 2. Eye Gaze Check (Pixel-Based Pupil Detection)
        var eyesLookingAway = false

        if let pixelBuffer = pixelBuffer,
            let leftEye = landmarks.leftEye,
            let rightEye = landmarks.rightEye,
            EyeTrackingConstants.pixelGazeEnabled
        {
            var leftGazeRatio: Double? = nil
            var rightGazeRatio: Double? = nil

            // Detect left pupil (side = 0)
            if let leftResult = PupilDetector.detectPupil(
                in: pixelBuffer,
                eyeLandmarks: leftEye,
                faceBoundingBox: face.boundingBox,
                imageSize: imageSize,
                side: 0
            ) {
                leftGazeRatio = calculateGazeRatio(
                    pupilPosition: leftResult.pupilPosition,
                    eyeRegion: leftResult.eyeRegion
                )
            }

            // Detect right pupil (side = 1)
            if let rightResult = PupilDetector.detectPupil(
                in: pixelBuffer,
                eyeLandmarks: rightEye,
                faceBoundingBox: face.boundingBox,
                imageSize: imageSize,
                side: 1
            ) {
                rightGazeRatio = calculateGazeRatio(
                    pupilPosition: rightResult.pupilPosition,
                    eyeRegion: rightResult.eyeRegion
                )
            }

            // CRITICAL: Connect to CalibrationManager
            if CalibrationManager.shared.isCalibrating,
                let leftRatio = leftGazeRatio,
                let rightRatio = rightGazeRatio
            {
                CalibrationManager.shared.collectSample(
                    leftRatio: leftRatio,
                    rightRatio: rightRatio
                )
            }

// Determine looking away using calibrated thresholds
             if let leftRatio = leftGazeRatio, let rightRatio = rightGazeRatio {
                 let avgRatio = (leftRatio + rightRatio) / 2.0
                 let lookingRight = avgRatio <= EyeTrackingConstants.pixelGazeMinRatio
                 let lookingLeft = avgRatio >= EyeTrackingConstants.pixelGazeMaxRatio
                 eyesLookingAway = lookingRight || lookingLeft

                if shouldLog {
                    print(
                        "👁️ PIXEL GAZE: L=\(String(format: "%.3f", leftRatio)) R=\(String(format: "%.3f", rightRatio)) Avg=\(String(format: "%.3f", avgRatio)) Away=\(eyesLookingAway)"
                    )
                    print(
                        "   Thresholds: Min=\(String(format: "%.3f", EyeTrackingConstants.pixelGazeMinRatio)) Max=\(String(format: "%.3f", EyeTrackingConstants.pixelGazeMaxRatio))"
                    )
                }
            } else {
                if shouldLog {
                    print("⚠️ Pixel pupil detection failed for one or both eyes")
                }
            }

            // Update debug values
            Task { @MainActor in
                debugLeftPupilRatio = leftGazeRatio
                debugRightPupilRatio = rightGazeRatio
            }
        } else {
            if shouldLog {
                if pixelBuffer == nil {
                    print("⚠️ No pixel buffer available for pupil detection")
                } else if !EyeTrackingConstants.pixelGazeEnabled {
                    print("⚠️ Pixel gaze detection disabled in constants")
                } else {
                    print("⚠️ Missing eye landmarks for pupil detection")
                }
            }
        }

        let isLookingAway = poseLookingAway || eyesLookingAway

        return isLookingAway
    }

    /// Calculate gaze ratio using Python GazeTracking algorithm
    /// Formula: ratio = pupilX / (eyeCenterX * 2 - 10)
    /// Returns: 0.0-1.0 (0.0 = far right, 1.0 = far left)
    private func calculateGazeRatio(pupilPosition: PupilPosition, eyeRegion: EyeRegion) -> Double {
        let pupilX = Double(pupilPosition.x)
        let eyeCenterX = Double(eyeRegion.center.x)

        // Python formula from GazeTracking library
        let denominator = (eyeCenterX * 2.0 - 10.0)

        guard denominator > 0 else {
            // Fallback to simple normalized position
            let eyeLeft = Double(eyeRegion.frame.minX)
            let eyeRight = Double(eyeRegion.frame.maxX)
            let eyeWidth = eyeRight - eyeLeft
            guard eyeWidth > 0 else { return 0.5 }
            return (pupilX - eyeLeft) / eyeWidth
        }

        let ratio = pupilX / denominator

        // Clamp to valid range
        return max(0.0, min(1.0, ratio))
    }

}

extension EyeTrackingService: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let request = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                print("Face detection error: \(error)")
                return
            }

            let size = CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )

            // Process face observations on the video queue (not main thread)
            // to avoid UI freezes from heavy pupil detection
            let observations = request.results as? [VNFaceObservation]
            let result = self.processFaceObservationsSync(
                observations,
                imageSize: size,
                pixelBuffer: pixelBuffer
            )

            // Only dispatch UI updates to main thread
            Task { @MainActor in
                self.faceDetected = result.faceDetected
                self.isEyesClosed = result.isEyesClosed
                self.userLookingAtScreen = result.userLookingAtScreen
                self.debugLeftPupilRatio = result.debugLeftPupilRatio
                self.debugRightPupilRatio = result.debugRightPupilRatio
                self.debugYaw = result.debugYaw
                self.debugPitch = result.debugPitch
            }
        }

        // Use revision 3 which includes more detailed landmarks including pupils
        request.revision = VNDetectFaceLandmarksRequestRevision3

        // Enable constellation points which may help with pose estimation
        if #available(macOS 14.0, *) {
            request.constellation = .constellation76Points
        }

        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .leftMirrored,
            options: [:]
        )

        do {
            try imageRequestHandler.perform([request])
        } catch {
            print("Failed to perform face detection: \(error)")
        }
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
