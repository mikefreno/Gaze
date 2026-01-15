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

    private func processFaceObservations(_ observations: [VNFaceObservation]?, imageSize: CGSize) {
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
            shouldLog: enableDebugLogging
        )
        userLookingAtScreen = !lookingAway
    }

    private func detectEyesClosed(
        leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D, shouldLog: Bool
    ) -> Bool {
        let constants = EyeTrackingConstants.shared

        // If eye closure detection is disabled, always return false (eyes not closed)
        guard constants.eyeClosedEnabled else {
            return false
        }

        guard leftEye.pointCount >= 2, rightEye.pointCount >= 2 else {
            return false
        }

        let leftEyeHeight = calculateEyeHeight(leftEye, shouldLog: shouldLog)
        let rightEyeHeight = calculateEyeHeight(rightEye, shouldLog: shouldLog)

        let closedThreshold = constants.eyeClosedThreshold

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
        face: VNFaceObservation, landmarks: VNFaceLandmarks2D, imageSize: CGSize, shouldLog: Bool
    ) -> Bool {
        let constants = EyeTrackingConstants.shared

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
            if constants.yawEnabled {
                let yawThreshold = constants.yawThreshold
                if abs(yaw) > yawThreshold {
                    poseLookingAway = true
                }
            }

            // Check pitch if either threshold is enabled
            if !poseLookingAway {
                var pitchLookingAway = false

                if constants.pitchUpEnabled && pitch > constants.pitchUpThreshold {
                    pitchLookingAway = true
                }

                if constants.pitchDownEnabled && pitch < constants.pitchDownThreshold {
                    pitchLookingAway = true
                }

                poseLookingAway = pitchLookingAway
            }
        }

        // 2. Eye Gaze Check (Pupil Position)
        var eyesLookingAway = false

        if let leftEye = landmarks.leftEye,
            let rightEye = landmarks.rightEye,
            let leftPupil = landmarks.leftPupil,
            let rightPupil = landmarks.rightPupil
        {
            
            // NEW: Use inter-eye distance method
            let gazeOffsets = calculateGazeUsingInterEyeDistance(
                leftEye: leftEye,
                rightEye: rightEye,
                leftPupil: leftPupil,
                rightPupil: rightPupil,
                imageSize: imageSize,
                faceBoundingBox: face.boundingBox
            )

            let leftRatio = calculatePupilHorizontalRatio(
                eye: leftEye,
                pupil: leftPupil,
                imageSize: imageSize,
                faceBoundingBox: face.boundingBox
            )
            let rightRatio = calculatePupilHorizontalRatio(
                eye: rightEye,
                pupil: rightPupil,
                imageSize: imageSize,
                faceBoundingBox: face.boundingBox
            )

            // Debug logging
            if shouldLog {
                print(
                    "👁️ Pupil Ratios (OLD METHOD) - Left: \(String(format: "%.3f", leftRatio)), Right: \(String(format: "%.3f", rightRatio))"
                )
                print(
                    "👁️ Gaze Offsets (NEW METHOD) - Left: \(String(format: "%.3f", gazeOffsets.leftGaze)), Right: \(String(format: "%.3f", gazeOffsets.rightGaze))"
                )
                print(
                    "👁️ Thresholds - Min: \(constants.minPupilRatio), Max: \(constants.maxPupilRatio)"
                )
            }

            // Update debug values
            Task { @MainActor in
                debugLeftPupilRatio = leftRatio
                debugRightPupilRatio = rightRatio
            }

            // Normal range for "looking center" is roughly 0.3 to 0.7
            // (0.0 = extreme right, 1.0 = extreme left relative to face)
            // Note: Camera is mirrored, so logic might be inverted

            var leftLookingAway = false
            var rightLookingAway = false

            // Check min pupil ratio if enabled
            /*if constants.minPupilEnabled {*/
            /*let minRatio = constants.minPupilRatio*/
            /*if leftRatio < minRatio {*/
            /*leftLookingAway = true*/
            /*}*/
            /*if rightRatio < minRatio {*/
            /*rightLookingAway = true*/
            /*}*/
            /*}*/

            /*// Check max pupil ratio if enabled*/
            /*if constants.maxPupilEnabled {*/
            /*let maxRatio = constants.maxPupilRatio*/
            /*if leftRatio > maxRatio {*/
            /*leftLookingAway = true*/
            /*}*/
            /*if rightRatio > maxRatio {*/
            /*rightLookingAway = true*/
            /*}*/
            /*}*/

            // Consider looking away if EITHER eye is off-center
            // Changed from AND to OR logic because requiring both eyes makes detection too restrictive
            // This is more sensitive but also more reliable for detecting actual looking away
            eyesLookingAway = leftLookingAway || rightLookingAway

            if shouldLog {
                print(
                    "👁️ Looking Away - Left: \(leftLookingAway), Right: \(rightLookingAway), Either: \(eyesLookingAway)"
                )
            }
        } else {
            if shouldLog {
                print("👁️ Missing pupil or eye landmarks!")
            }
        }

        let isLookingAway = poseLookingAway || eyesLookingAway

        return isLookingAway
    }

    private func calculatePupilHorizontalRatio(
        eye: VNFaceLandmarkRegion2D,
        pupil: VNFaceLandmarkRegion2D,
        imageSize: CGSize,
        faceBoundingBox: CGRect
    ) -> Double {
        // Use normalizedPoints which are already normalized to face bounding box
        let eyePoints = eye.normalizedPoints
        let pupilPoints = pupil.normalizedPoints

        // Throttle debug logging to every 0.5 seconds
        let now = Date()
        let shouldLog = now.timeIntervalSince(lastDebugLogTime) >= 0.5

        if shouldLog {
            lastDebugLogTime = now

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 EYE TRACKING DEBUG DATA")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            print("\n🖼️  IMAGE SIZE:")
            print("   Width: \(imageSize.width), Height: \(imageSize.height)")

            print("\n📦 FACE BOUNDING BOX (normalized):")
            print("   Origin: (\(faceBoundingBox.origin.x), \(faceBoundingBox.origin.y))")
            print("   Size: (\(faceBoundingBox.size.width), \(faceBoundingBox.size.height))")

            print("\n👁️  EYE LANDMARK POINTS (normalized to face bounding box - from Vision):")
            print("   Count: \(eyePoints.count)")
            let eyeMinX = eyePoints.min(by: { $0.x < $1.x })?.x ?? 0
            let eyeMaxX = eyePoints.max(by: { $0.x < $1.x })?.x ?? 0
            for (index, point) in eyePoints.enumerated() {
                var marker = ""
                if abs(point.x - eyeMinX) < 0.0001 {
                    marker = " ← LEFTMOST (inner corner)"
                } else if abs(point.x - eyeMaxX) < 0.0001 {
                    marker = " ← RIGHTMOST (outer corner)"
                }
                if index == 0 {
                    marker += " [FIRST]"
                } else if index == eyePoints.count - 1 {
                    marker += " [LAST]"
                }
                print(
                    "   [\(index)]: (\(String(format: "%.4f", point.x)), \(String(format: "%.4f", point.y)))\(marker)"
                )
            }

            print("\n👁️  PUPIL LANDMARK POINTS (normalized to face bounding box - from Vision):")
            print("   Count: \(pupilPoints.count)")
            for (index, point) in pupilPoints.enumerated() {
                print(
                    "   [\(index)]: (\(String(format: "%.4f", point.x)), \(String(format: "%.4f", point.y)))"
                )
            }

            if let minPoint = eyePoints.min(by: { $0.x < $1.x }),
                let maxPoint = eyePoints.max(by: { $0.x < $1.x })
            {
                let eyeMinX = minPoint.x
                let eyeMaxX = maxPoint.x
                let eyeWidth = eyeMaxX - eyeMinX
                let pupilCenterX = pupilPoints.map { $0.x }.reduce(0, +) / Double(pupilPoints.count)
                let ratio = (pupilCenterX - eyeMinX) / eyeWidth

                print("\n📏 CALCULATIONS:")
                print("   Eye MinX: \(String(format: "%.4f", eyeMinX))")
                print("   Eye MaxX: \(String(format: "%.4f", eyeMaxX))")
                print("   Eye Width: \(String(format: "%.4f", eyeWidth))")
                
                // Analyze different point pairs to find better eye width
                if eyePoints.count >= 6 {
                    let cornerWidth = eyePoints[5].x - eyePoints[0].x
                    print("   Corner-to-Corner Width [0→5]: \(String(format: "%.4f", cornerWidth))")
                    
                    // Try middle points too
                    if eyePoints.count >= 4 {
                        let midWidth = eyePoints[3].x - eyePoints[0].x
                        print("   Point [0→3] Width: \(String(format: "%.4f", midWidth))")
                    }
                }
                
                print("   Pupil Center X: \(String(format: "%.4f", pupilCenterX))")
                print("   Pupil Min X: \(String(format: "%.4f", pupilPoints.min(by: { $0.x < $1.x })?.x ?? 0))")
                print("   Pupil Max X: \(String(format: "%.4f", pupilPoints.max(by: { $0.x < $1.x })?.x ?? 0))")
                print("   Final Ratio (current method): \(String(format: "%.4f", ratio))")
                
                // Calculate alternate ratios
                if eyePoints.count >= 6 {
                    let cornerWidth = eyePoints[5].x - eyePoints[0].x
                    if cornerWidth > 0 {
                        let cornerRatio = (pupilCenterX - eyePoints[0].x) / cornerWidth
                        print("   Alternate Ratio (using corners [0→5]): \(String(format: "%.4f", cornerRatio))")
                    }
                }
            }

            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        }

        guard !eyePoints.isEmpty, !pupilPoints.isEmpty else { return 0.5 }

        guard let minPoint = eyePoints.min(by: { $0.x < $1.x }),
            let maxPoint = eyePoints.max(by: { $0.x < $1.x })
        else {
            return 0.5
        }

        let eyeMinX = minPoint.x
        let eyeMaxX = maxPoint.x
        let eyeWidth = eyeMaxX - eyeMinX

        guard eyeWidth > 0 else { return 0.5 }

        let pupilCenterX = pupilPoints.map { $0.x }.reduce(0, +) / Double(pupilPoints.count)

        // Calculate ratio (0.0 to 1.0) - already normalized to face bounding box by Vision
        let ratio = (pupilCenterX - eyeMinX) / eyeWidth

        return ratio
    }
    
    /// NEW APPROACH: Calculate gaze using inter-eye distance as reference
    /// This works around Vision's limitation that eye landmarks only track the iris, not true eye corners
    private func calculateGazeUsingInterEyeDistance(
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D,
        leftPupil: VNFaceLandmarkRegion2D,
        rightPupil: VNFaceLandmarkRegion2D,
        imageSize: CGSize,
        faceBoundingBox: CGRect
    ) -> (leftGaze: Double, rightGaze: Double) {
        
        // CRITICAL: Convert from face-normalized coordinates to image coordinates
        // normalizedPoints are relative to face bounding box, not stable for gaze tracking
        
        // Helper to convert face-normalized point to image coordinates
        func toImageCoords(_ point: CGPoint) -> CGPoint {
            // Face bounding box origin is in Vision coordinates (bottom-left origin)
            let imageX = faceBoundingBox.origin.x + point.x * faceBoundingBox.width
            let imageY = faceBoundingBox.origin.y + point.y * faceBoundingBox.height
            return CGPoint(x: imageX, y: imageY)
        }
        
        // Convert all points to image space
        let leftEyePointsImg = leftEye.normalizedPoints.map { toImageCoords($0) }
        let rightEyePointsImg = rightEye.normalizedPoints.map { toImageCoords($0) }
        let leftPupilPointsImg = leftPupil.normalizedPoints.map { toImageCoords($0) }
        let rightPupilPointsImg = rightPupil.normalizedPoints.map { toImageCoords($0) }
        
        // Calculate eye centers (average of all iris boundary points)
        let leftEyeCenterX = leftEyePointsImg.map { $0.x }.reduce(0, +) / Double(leftEyePointsImg.count)
        let rightEyeCenterX = rightEyePointsImg.map { $0.x }.reduce(0, +) / Double(rightEyePointsImg.count)
        
        // Calculate pupil centers
        let leftPupilX = leftPupilPointsImg.map { $0.x }.reduce(0, +) / Double(leftPupilPointsImg.count)
        let rightPupilX = rightPupilPointsImg.map { $0.x }.reduce(0, +) / Double(rightPupilPointsImg.count)
        
        // Inter-eye distance (the distance between eye centers) - should be stable now
        let interEyeDistance = abs(rightEyeCenterX - leftEyeCenterX)
        
        // Estimate iris width as a fraction of inter-eye distance
        // Typical human: inter-pupil distance ~63mm, iris width ~12mm → ratio ~1/5
        let irisWidth = interEyeDistance / 5.0
        
        // Calculate gaze offset for each eye (positive = looking right, negative = looking left)
        let leftGazeOffset = (leftPupilX - leftEyeCenterX) / irisWidth
        let rightGazeOffset = (rightPupilX - rightEyeCenterX) / irisWidth
        
        // Throttle debug logging
        let now = Date()
        let shouldLog = now.timeIntervalSince(lastDebugLogTime) >= 0.5
        
        if shouldLog {
            lastDebugLogTime = now
            
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 INTER-EYE DISTANCE GAZE (IMAGE COORDS)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            
            print("\n🖼️  IMAGE SPACE:")
            print("   Image Size: \(Int(imageSize.width)) x \(Int(imageSize.height))")
            print("   Face Box: x=\(String(format: "%.3f", faceBoundingBox.origin.x)) w=\(String(format: "%.3f", faceBoundingBox.width))")
            
            print("\n👁️  EYE CENTERS (image coords):")
            print("   Left Eye Center X: \(String(format: "%.4f", leftEyeCenterX)) (\(Int(leftEyeCenterX * imageSize.width))px)")
            print("   Right Eye Center X: \(String(format: "%.4f", rightEyeCenterX)) (\(Int(rightEyeCenterX * imageSize.width))px)")
            print("   Inter-Eye Distance: \(String(format: "%.4f", interEyeDistance)) (\(Int(interEyeDistance * imageSize.width))px)")
            print("   Estimated Iris Width: \(String(format: "%.4f", irisWidth)) (\(Int(irisWidth * imageSize.width))px)")
            
            print("\n👁️  PUPIL POSITIONS (image coords):")
            print("   Left Pupil X: \(String(format: "%.4f", leftPupilX)) (\(Int(leftPupilX * imageSize.width))px)")
            print("   Right Pupil X: \(String(format: "%.4f", rightPupilX)) (\(Int(rightPupilX * imageSize.width))px)")
            
            print("\n📏 PUPIL OFFSETS FROM EYE CENTER:")
            print("   Left Offset: \(String(format: "%.4f", leftPupilX - leftEyeCenterX)) (\(Int((leftPupilX - leftEyeCenterX) * imageSize.width))px)")
            print("   Right Offset: \(String(format: "%.4f", rightPupilX - rightEyeCenterX)) (\(Int((rightPupilX - rightEyeCenterX) * imageSize.width))px)")
            
            print("\n📏 GAZE OFFSETS (normalized to iris width):")
            print("   Left Gaze Offset: \(String(format: "%.4f", leftGazeOffset)) (0=center, +right, -left)")
            print("   Right Gaze Offset: \(String(format: "%.4f", rightGazeOffset)) (0=center, +right, -left)")
            print("   Average Gaze: \(String(format: "%.4f", (leftGazeOffset + rightGazeOffset) / 2))")
            
            // Interpretation
            let avgGaze = (leftGazeOffset + rightGazeOffset) / 2
            var interpretation = ""
            if avgGaze < -0.5 {
                interpretation = "Looking LEFT"
            } else if avgGaze > 0.5 {
                interpretation = "Looking RIGHT"
            } else {
                interpretation = "Looking CENTER"
            }
            print("   Interpretation: \(interpretation)")
            
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        }
        
        return (leftGazeOffset, rightGazeOffset)
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

            Task { @MainActor in
                self.processFaceObservations(
                    request.results as? [VNFaceObservation],
                    imageSize: size
                )
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
