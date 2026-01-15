//
//  EyeTrackingService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import Combine
import Vision

@MainActor
class EyeTrackingService: NSObject, ObservableObject {
    static let shared = EyeTrackingService()
    
    @Published var isEyeTrackingActive = false
    @Published var isEyesClosed = false
    @Published var userLookingAtScreen = true
    @Published var faceDetected = false
    
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoDataOutputQueue = DispatchQueue(label: "com.gaze.videoDataOutput", qos: .userInitiated)
    private var _previewLayer: AVCaptureVideoPreviewLayer?
    
    // Logging throttle
    private var lastLogTime: Date = .distantPast
    private let logInterval: TimeInterval = 0.5 // Log every 0.5 seconds
    
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
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        output.alwaysDiscardsLateVideoFrames = true
        
        guard session.canAddOutput(output) else {
            throw EyeTrackingError.cannotAddOutput
        }
        session.addOutput(output)
        
        self.captureSession = session
        self.videoOutput = output
    }
    
    private func processFaceObservations(_ observations: [VNFaceObservation]?) {
        let shouldLog = Date().timeIntervalSince(lastLogTime) >= logInterval
        
        if shouldLog {
            print("🔍 Processing face observations...")
        }
        
        guard let observations = observations, !observations.isEmpty else {
            if shouldLog {
                print("❌ No faces detected")
            }
            faceDetected = false
            userLookingAtScreen = false
            return
        }
        
        faceDetected = true
        let face = observations.first!
        
        if shouldLog {
            print("✅ Face detected. Bounding box: \(face.boundingBox)")
        }
        
        guard let landmarks = face.landmarks else {
            if shouldLog {
                print("❌ No face landmarks detected")
            }
            return
        }
        
        // Check eye closure
        if let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye {
            let eyesClosed = detectEyesClosed(leftEye: leftEye, rightEye: rightEye, shouldLog: shouldLog)
            self.isEyesClosed = eyesClosed
        }
        
        // Check gaze direction
        let lookingAway = detectLookingAway(face: face, landmarks: landmarks, shouldLog: shouldLog)
        userLookingAtScreen = !lookingAway
        
        if shouldLog {
            lastLogTime = Date()
        }
    }
    
    private func detectEyesClosed(leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D, shouldLog: Bool) -> Bool {
        guard leftEye.pointCount >= 2, rightEye.pointCount >= 2 else {
            if shouldLog {
                print("⚠️ Eye landmarks insufficient for eye closure detection")
            }
            return false
        }
        
        let leftEyeHeight = calculateEyeHeight(leftEye, shouldLog: shouldLog)
        let rightEyeHeight = calculateEyeHeight(rightEye, shouldLog: shouldLog)
        
        let closedThreshold: CGFloat = 0.02
        
        let isClosed = leftEyeHeight < closedThreshold && rightEyeHeight < closedThreshold
        
        if shouldLog {
            print("👁️ Eye closure detection - Left: \(leftEyeHeight) < \(closedThreshold) = \(leftEyeHeight < closedThreshold), Right: \(rightEyeHeight) < \(closedThreshold) = \(rightEyeHeight < closedThreshold)")
            print("👁️ Eyes closed: \(isClosed)")
        }
        
        return isClosed
    }
    
    private func calculateEyeHeight(_ eye: VNFaceLandmarkRegion2D, shouldLog: Bool) -> CGFloat {
        let points = eye.normalizedPoints
        guard points.count >= 2 else { return 0 }
        
        let yValues = points.map { $0.y }
        let maxY = yValues.max() ?? 0
        let minY = yValues.min() ?? 0
        
        let height = abs(maxY - minY)
        
        if shouldLog {
            print("📏 Eye height: \(height)")
        }
        
        return height
    }
    
    private func detectLookingAway(face: VNFaceObservation, landmarks: VNFaceLandmarks2D, shouldLog: Bool) -> Bool {
        // 1. Face Pose Check (Yaw & Pitch)
        let yaw = face.yaw?.doubleValue ?? 0.0
        let pitch = face.pitch?.doubleValue ?? 0.0
        
        let yawThreshold = 0.35   // ~20 degrees
        let pitchThreshold = 0.4  // ~23 degrees
        
        let poseLookingAway = abs(yaw) > yawThreshold || abs(pitch) > pitchThreshold
        
        // 2. Eye Gaze Check (Pupil Position)
        var eyesLookingAway = false
        
        if let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye,
           let leftPupil = landmarks.leftPupil,
           let rightPupil = landmarks.rightPupil {
            
            let leftRatio = calculatePupilHorizontalRatio(eye: leftEye, pupil: leftPupil)
            let rightRatio = calculatePupilHorizontalRatio(eye: rightEye, pupil: rightPupil)
            
            // Normal range for "looking center" is roughly 0.3 to 0.7
            // (0.0 = extreme right, 1.0 = extreme left relative to face)
            // Note: Camera is mirrored, so logic might be inverted
            
            let minRatio = 0.25
            let maxRatio = 0.75
            
            let leftLookingAway = leftRatio < minRatio || leftRatio > maxRatio
            let rightLookingAway = rightRatio < minRatio || rightRatio > maxRatio
            
            // Consider looking away if BOTH eyes are off-center
            eyesLookingAway = leftLookingAway && rightLookingAway
            
            if shouldLog {
                print("👁️ Pupil Ratios - Left: \(String(format: "%.2f", leftRatio)), Right: \(String(format: "%.2f", rightRatio))")
                print("👁️ Eyes Looking Away: \(eyesLookingAway)")
            }
        }
        
        let isLookingAway = poseLookingAway || eyesLookingAway
        
        if shouldLog {
            print("📊 Gaze detection - Yaw: \(yaw), Pitch: \(pitch)")
            print("📉 Thresholds - Yaw: \(yawThreshold), Pitch: \(pitchThreshold)")
            print("🎯 Looking away: \(isLookingAway) (Pose: \(poseLookingAway), Eyes: \(eyesLookingAway))")
            print("👀 User looking at screen: \(!isLookingAway)")
        }
        
        return isLookingAway
    }
    
    private func calculatePupilHorizontalRatio(eye: VNFaceLandmarkRegion2D, pupil: VNFaceLandmarkRegion2D) -> Double {
        let eyePoints = eye.normalizedPoints
        let pupilPoints = pupil.normalizedPoints
        
        guard !eyePoints.isEmpty, !pupilPoints.isEmpty else { return 0.5 }
        
        // Get eye horizontal bounds
        let eyeMinX = eyePoints.map { $0.x }.min() ?? 0
        let eyeMaxX = eyePoints.map { $0.x }.max() ?? 0
        let eyeWidth = eyeMaxX - eyeMinX
        
        guard eyeWidth > 0 else { return 0.5 }
        
        // Get pupil center X
        let pupilCenterX = pupilPoints.map { $0.x }.reduce(0, +) / Double(pupilPoints.count)
        
        // Calculate ratio (0.0 to 1.0)
        // 0.0 = Right side of eye (camera view)
        // 1.0 = Left side of eye (camera view)
        let ratio = (pupilCenterX - eyeMinX) / eyeWidth
        
        return ratio
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

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
            
            Task { @MainActor in
                self.processFaceObservations(request.results as? [VNFaceObservation])
            }
        }
        
        request.revision = VNDetectFaceLandmarksRequestRevision3
        
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
