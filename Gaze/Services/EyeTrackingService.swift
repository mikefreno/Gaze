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
import AppKit

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
    @Published var debugLeftVerticalRatio: Double?
    @Published var debugRightVerticalRatio: Double?
    @Published var debugYaw: Double?
    @Published var debugPitch: Double?
    @Published var enableDebugLogging: Bool = false {
        didSet {
            // Sync with PupilDetector's diagnostic logging
            PupilDetector.enableDiagnosticLogging = enableDebugLogging
        }
    }
    
    // Debug eye images for UI display
    @Published var debugLeftEyeInput: NSImage?
    @Published var debugRightEyeInput: NSImage?
    @Published var debugLeftEyeProcessed: NSImage?
    @Published var debugRightEyeProcessed: NSImage?
    @Published var debugLeftPupilPosition: PupilPosition?
    @Published var debugRightPupilPosition: PupilPosition?
    @Published var debugLeftEyeSize: CGSize?
    @Published var debugRightEyeSize: CGSize?
    
    // Eye region positions for video overlay
    @Published var debugLeftEyeRegion: EyeRegion?
    @Published var debugRightEyeRegion: EyeRegion?
    @Published var debugImageSize: CGSize?
    
    // Computed gaze direction for UI overlay
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
        var debugLeftVerticalRatio: Double?
        var debugRightVerticalRatio: Double?
        var debugYaw: Double?
        var debugPitch: Double?
        
        nonisolated init(
            faceDetected: Bool = false,
            isEyesClosed: Bool = false,
            userLookingAtScreen: Bool = true,
            debugLeftPupilRatio: Double? = nil,
            debugRightPupilRatio: Double? = nil,
            debugLeftVerticalRatio: Double? = nil,
            debugRightVerticalRatio: Double? = nil,
            debugYaw: Double? = nil,
            debugPitch: Double? = nil
        ) {
            self.faceDetected = faceDetected
            self.isEyesClosed = isEyesClosed
            self.userLookingAtScreen = userLookingAtScreen
            self.debugLeftPupilRatio = debugLeftPupilRatio
            self.debugRightPupilRatio = debugRightPupilRatio
            self.debugLeftVerticalRatio = debugLeftVerticalRatio
            self.debugRightVerticalRatio = debugRightVerticalRatio
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

        // Always extract yaw/pitch from face, even if landmarks aren't available
        result.debugYaw = face.yaw?.doubleValue ?? 0.0
        result.debugPitch = face.pitch?.doubleValue ?? 0.0

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
        result.debugLeftVerticalRatio = gazeResult.leftVerticalRatio
        result.debugRightVerticalRatio = gazeResult.rightVerticalRatio
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
        var leftVerticalRatio: Double?
        var rightVerticalRatio: Double?
        var yaw: Double?
        var pitch: Double?
        
        nonisolated init(
            lookingAway: Bool = false,
            leftPupilRatio: Double? = nil,
            rightPupilRatio: Double? = nil,
            leftVerticalRatio: Double? = nil,
            rightVerticalRatio: Double? = nil,
            yaw: Double? = nil,
            pitch: Double? = nil
        ) {
            self.lookingAway = lookingAway
            self.leftPupilRatio = leftPupilRatio
            self.rightPupilRatio = rightPupilRatio
            self.leftVerticalRatio = leftVerticalRatio
            self.rightVerticalRatio = rightVerticalRatio
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
            var leftVerticalRatio: Double? = nil
            var rightVerticalRatio: Double? = nil

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
                leftVerticalRatio = calculateVerticalRatioSync(
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
                rightVerticalRatio = calculateVerticalRatioSync(
                    pupilPosition: rightResult.pupilPosition,
                    eyeRegion: rightResult.eyeRegion
                )
            }

            result.leftPupilRatio = leftGazeRatio
            result.rightPupilRatio = rightGazeRatio
            result.leftVerticalRatio = leftVerticalRatio
            result.rightVerticalRatio = rightVerticalRatio

            // Connect to CalibrationManager on main thread
            if let leftRatio = leftGazeRatio,
                let rightRatio = rightGazeRatio
            {
                let faceWidth = face.boundingBox.width
                
                Task { @MainActor in
                    if CalibrationManager.shared.isCalibrating {
                        CalibrationManager.shared.collectSample(
                            leftRatio: leftRatio,
                            rightRatio: rightRatio,
                            leftVertical: leftVerticalRatio,
                            rightVertical: rightVerticalRatio,
                            faceWidthRatio: faceWidth
                        )
                    }
                }

                let avgH = (leftRatio + rightRatio) / 2.0
                // Use 0.5 as default for vertical if not available
                let avgV = (leftVerticalRatio != nil && rightVerticalRatio != nil)
                    ? (leftVerticalRatio! + rightVerticalRatio!) / 2.0
                    : 0.5
                
                // Use Calibrated Thresholds from thread-safe state
                if let thresholds = CalibrationState.shared.thresholds,
                   CalibrationState.shared.isComplete {
                    
                    // 1. Distance Scaling using face width as proxy
                    // When user is farther from screen, face appears smaller and eye movements
                    // (in ratio terms) compress toward center. We scale to compensate.
                    let currentFaceWidth = face.boundingBox.width
                    let refFaceWidth = thresholds.referenceFaceWidth
                    
                    var distanceScale = 1.0
                    if refFaceWidth > 0 && currentFaceWidth > 0 {
                        // ratio > 1 means user is farther than calibration distance
                        // ratio < 1 means user is closer than calibration distance
                        let rawScale = refFaceWidth / currentFaceWidth
                        // Apply sensitivity factor and clamp to reasonable range
                        distanceScale = 1.0 + (rawScale - 1.0) * EyeTrackingConstants.distanceSensitivity
                        distanceScale = max(0.5, min(2.0, distanceScale))  // Clamp to 0.5x - 2x
                    }
                    
                    // 2. Calculate calibrated center point
                    let centerH = (thresholds.screenLeftBound + thresholds.screenRightBound) / 2.0
                    let centerV = (thresholds.screenTopBound + thresholds.screenBottomBound) / 2.0
                    
                    // 3. Normalize gaze relative to center, scaled for distance
                    // When farther away, eye movements are smaller, so we amplify them
                    let deltaH = (avgH - centerH) * distanceScale
                    let deltaV = (avgV - centerV) * distanceScale
                    
                    let normalizedH = centerH + deltaH
                    let normalizedV = centerV + deltaV
                    
                    // 4. Boundary Check - compare against screen bounds
                    // Looking away = gaze is beyond the calibrated screen edges
                    let margin = EyeTrackingConstants.boundaryForgivenessMargin
                    
                    let isLookingLeft = normalizedH > (thresholds.screenLeftBound + margin)
                    let isLookingRight = normalizedH < (thresholds.screenRightBound - margin)
                    let isLookingUp = normalizedV < (thresholds.screenTopBound - margin)
                    let isLookingDown = normalizedV > (thresholds.screenBottomBound + margin)
                    
                    eyesLookingAway = isLookingLeft || isLookingRight || isLookingUp || isLookingDown
                    
                } else {
                    // Fallback to default constants (no calibration)
                    // Still apply distance scaling using default reference
                    let currentFaceWidth = face.boundingBox.width
                    let refFaceWidth = EyeTrackingConstants.defaultReferenceFaceWidth
                    
                    var distanceScale = 1.0
                    if refFaceWidth > 0 && currentFaceWidth > 0 {
                        let rawScale = refFaceWidth / currentFaceWidth
                        distanceScale = 1.0 + (rawScale - 1.0) * EyeTrackingConstants.distanceSensitivity
                        distanceScale = max(0.5, min(2.0, distanceScale))
                    }
                    
                    // Center is assumed at midpoint of the thresholds
                    let centerH = (EyeTrackingConstants.pixelGazeMinRatio + EyeTrackingConstants.pixelGazeMaxRatio) / 2.0
                    let normalizedH = centerH + (avgH - centerH) * distanceScale
                    
                    let lookingRight = normalizedH <= EyeTrackingConstants.pixelGazeMinRatio
                    let lookingLeft = normalizedH >= EyeTrackingConstants.pixelGazeMaxRatio
                    eyesLookingAway = lookingRight || lookingLeft
                }
            }
        }

        result.lookingAway = poseLookingAway || eyesLookingAway
        return result
    }

    /// Non-isolated horizontal gaze ratio calculation
    /// pupilPosition.y controls horizontal gaze (left-right) due to image orientation
    /// Returns 0.0 for left edge, 1.0 for right edge, 0.5 for center
    nonisolated private func calculateGazeRatioSync(
        pupilPosition: PupilPosition, eyeRegion: EyeRegion
    ) -> Double {
        let pupilY = Double(pupilPosition.y)
        let eyeHeight = Double(eyeRegion.frame.height)
        
        guard eyeHeight > 0 else { return 0.5 }
        
        let ratio = pupilY / eyeHeight
        return max(0.0, min(1.0, ratio))
    }
    
    /// Non-isolated vertical gaze ratio calculation
    /// pupilPosition.x controls vertical gaze (up-down) due to image orientation
    /// Returns 0.0 for top edge (looking up), 1.0 for bottom edge (looking down), 0.5 for center
    nonisolated private func calculateVerticalRatioSync(
        pupilPosition: PupilPosition, eyeRegion: EyeRegion
    ) -> Double {
        let pupilX = Double(pupilPosition.x)
        let eyeWidth = Double(eyeRegion.frame.width)
        
        guard eyeWidth > 0 else { return 0.5 }
        
        let ratio = pupilX / eyeWidth
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
            var leftVerticalRatio: Double? = nil
            var rightVerticalRatio: Double? = nil

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
                leftVerticalRatio = calculateVerticalRatioSync(
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
                rightVerticalRatio = calculateVerticalRatioSync(
                    pupilPosition: rightResult.pupilPosition,
                    eyeRegion: rightResult.eyeRegion
                )
            }

            // CRITICAL: Connect to CalibrationManager
            if CalibrationManager.shared.isCalibrating,
                let leftRatio = leftGazeRatio,
                let rightRatio = rightGazeRatio
            {
                // Calculate face width ratio for distance estimation
                let faceWidthRatio = face.boundingBox.width
                
                CalibrationManager.shared.collectSample(
                    leftRatio: leftRatio,
                    rightRatio: rightRatio,
                    leftVertical: leftVerticalRatio,
                    rightVertical: rightVerticalRatio,
                    faceWidthRatio: faceWidthRatio
                )
            }

            // Determine looking away using calibrated thresholds
            if let leftRatio = leftGazeRatio, let rightRatio = rightGazeRatio {
                let avgH = (leftRatio + rightRatio) / 2.0
                // Use 0.5 as default for vertical if not available (though it should be)
                let avgV = (leftVerticalRatio != nil && rightVerticalRatio != nil) 
                    ? (leftVerticalRatio! + rightVerticalRatio!) / 2.0 
                    : 0.5
                
                 // Use Calibrated Thresholds if available
                 // Use thread-safe state instead of accessing CalibrationManager.shared (MainActor)
                 if let thresholds = CalibrationState.shared.thresholds,
                    CalibrationState.shared.isComplete {
                     
                     // 1. Distance Scaling
                    // If current face is SMALLER than reference, user is FURTHER away.
                    // Eyes move LESS for same screen angle. We need to SCALE UP the deviation.
                    let currentFaceWidth = face.boundingBox.width
                    let refFaceWidth = thresholds.referenceFaceWidth
                    
                    var distanceScale = 1.0
                    if refFaceWidth > 0 && currentFaceWidth > 0 {
                        // Simple linear scaling: scale = ref / current
                        // e.g. Ref=0.5, Current=0.25 (further) -> Scale=2.0
                        distanceScale = refFaceWidth / currentFaceWidth
                        
                        // Apply sensitivity tuning
                        distanceScale = 1.0 + (distanceScale - 1.0) * EyeTrackingConstants.distanceSensitivity
                    }
                    
                    // 2. Normalize Gaze (Center Relative)
                    // We assume ~0.5 is center. We scale the delta from 0.5.
                    // Note: This is an approximation. A better way uses the calibrated center.
                    let centerH = (thresholds.screenLeftBound + thresholds.screenRightBound) / 2.0
                    let centerV = (thresholds.screenTopBound + thresholds.screenBottomBound) / 2.0
                    
                    let deltaH = (avgH - centerH) * distanceScale
                    let deltaV = (avgV - centerV) * distanceScale
                    
                    let normalizedH = centerH + deltaH
                    let normalizedV = centerV + deltaV
                    
                    // 3. Boundary Check with Margin
                    // "Forgiveness" expands the safe zone (screen bounds).
                    // If you are IN the margin, you are considered ON SCREEN (Safe).
                    // Looking Away means passing the (Bound + Margin).
                    
                    let margin = EyeTrackingConstants.boundaryForgivenessMargin
                    
                    // Check Left (Higher Ratio)
                    // Screen Left is e.g. 0.7. Looking Left > 0.7.
                    // To look away, must exceed (0.7 + margin).
                    let isLookingLeft = normalizedH > (thresholds.screenLeftBound + margin)
                    
                    // Check Right (Lower Ratio)
                    // Screen Right is e.g. 0.3. Looking Right < 0.3.
                    // To look away, must be less than (0.3 - margin).
                    let isLookingRight = normalizedH < (thresholds.screenRightBound - margin)
                    
                    // Check Up (Lower Ratio, usually)
                    let isLookingUp = normalizedV < (thresholds.screenTopBound - margin)
                    
                    // Check Down (Higher Ratio, usually)
                    let isLookingDown = normalizedV > (thresholds.screenBottomBound + margin)
                    
                    eyesLookingAway = isLookingLeft || isLookingRight || isLookingUp || isLookingDown
                    
                    if shouldLog {
                        print("👁️ CALIBRATED GAZE: AvgH=\(String(format: "%.2f", avgH)) AvgV=\(String(format: "%.2f", avgV)) DistScale=\(String(format: "%.2f", distanceScale))")
                        print("   NormH=\(String(format: "%.2f", normalizedH)) NormV=\(String(format: "%.2f", normalizedV)) Away=\(eyesLookingAway)")
                        print("   Bounds: H[\(String(format: "%.2f", thresholds.screenRightBound))-\(String(format: "%.2f", thresholds.screenLeftBound))] V[\(String(format: "%.2f", thresholds.screenTopBound))-\(String(format: "%.2f", thresholds.screenBottomBound))]")
                    }
                    
                } else {
                    // Fallback to default constants
                    let lookingRight = avgH <= EyeTrackingConstants.pixelGazeMinRatio
                    let lookingLeft = avgH >= EyeTrackingConstants.pixelGazeMaxRatio
                    eyesLookingAway = lookingRight || lookingLeft
                }
                
                // Update debug values
                Task { @MainActor in
                    debugLeftPupilRatio = leftGazeRatio
                    debugRightPupilRatio = rightGazeRatio
                    debugLeftVerticalRatio = leftVerticalRatio
                    debugRightVerticalRatio = rightVerticalRatio
                }

                 if shouldLog && !CalibrationState.shared.isComplete {
                    print(
                        "👁️ RAW GAZE: L=\(String(format: "%.3f", leftRatio)) R=\(String(format: "%.3f", rightRatio)) Avg=\(String(format: "%.3f", avgH)) Away=\(eyesLookingAway)"
                    )
                 }
            } else {
                if shouldLog {
                    print("⚠️ Pixel pupil detection failed for one or both eyes")
                }
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
    // DEBUG: Frame counter for periodic logging (nonisolated for video callback)
    private nonisolated(unsafe) static var debugFrameCount = 0
    
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // DEBUG: Print every 30 frames to show we're receiving video
        #if DEBUG
        EyeTrackingService.debugFrameCount += 1
        if EyeTrackingService.debugFrameCount % 30 == 0 {
            NSLog("🎥 EyeTrackingService: Received frame %d", EyeTrackingService.debugFrameCount)
        }
        #endif
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Advance frame counter for pupil detector frame skipping
        PupilDetector.advanceFrame()

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
                self.debugLeftVerticalRatio = result.debugLeftVerticalRatio
                self.debugRightVerticalRatio = result.debugRightVerticalRatio
                self.debugYaw = result.debugYaw
                self.debugPitch = result.debugPitch
                
                // Update debug eye images from PupilDetector
                if let leftInput = PupilDetector.debugLeftEyeInput {
                    self.debugLeftEyeInput = NSImage(cgImage: leftInput, size: NSSize(width: leftInput.width, height: leftInput.height))
                }
                if let rightInput = PupilDetector.debugRightEyeInput {
                    self.debugRightEyeInput = NSImage(cgImage: rightInput, size: NSSize(width: rightInput.width, height: rightInput.height))
                }
                if let leftProcessed = PupilDetector.debugLeftEyeProcessed {
                    self.debugLeftEyeProcessed = NSImage(cgImage: leftProcessed, size: NSSize(width: leftProcessed.width, height: leftProcessed.height))
                }
                if let rightProcessed = PupilDetector.debugRightEyeProcessed {
                    self.debugRightEyeProcessed = NSImage(cgImage: rightProcessed, size: NSSize(width: rightProcessed.width, height: rightProcessed.height))
                }
                self.debugLeftPupilPosition = PupilDetector.debugLeftPupilPosition
                self.debugRightPupilPosition = PupilDetector.debugRightPupilPosition
                self.debugLeftEyeSize = PupilDetector.debugLeftEyeSize
                self.debugRightEyeSize = PupilDetector.debugRightEyeSize
                
                // Update eye region positions for video overlay
                self.debugLeftEyeRegion = PupilDetector.debugLeftEyeRegion
                self.debugRightEyeRegion = PupilDetector.debugRightEyeRegion
                self.debugImageSize = PupilDetector.debugImageSize
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
            orientation: .upMirrored,
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
