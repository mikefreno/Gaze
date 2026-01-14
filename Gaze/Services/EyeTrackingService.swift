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
        print("🔍 Processing face observations...")
        guard let observations = observations, !observations.isEmpty else {
            print("❌ No faces detected")
            faceDetected = false
            userLookingAtScreen = false
            return
        }
        
        faceDetected = true
        let face = observations.first!
        
        print("✅ Face detected. Bounding box: \(face.boundingBox)")
        
        guard let landmarks = face.landmarks else {
            print("❌ No face landmarks detected")
            return
        }
        
        // Log eye landmarks
        if let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye {
            print("👁️ Left eye landmarks: \(leftEye.pointCount) points")
            print("👁️ Right eye landmarks: \(rightEye.pointCount) points")
            
            let leftEyeHeight = calculateEyeHeight(leftEye)
            let rightEyeHeight = calculateEyeHeight(rightEye)
            
            print("👁️ Left eye height: \(leftEyeHeight)")
            print("👁️ Right eye height: \(rightEyeHeight)")
            
            let eyesClosed = detectEyesClosed(leftEye: leftEye, rightEye: rightEye)
            self.isEyesClosed = eyesClosed
            print("👁️ Eyes closed: \(eyesClosed)")
        }
        
        // Log gaze detection
        let lookingAway = detectLookingAway(face: face, landmarks: landmarks)
        userLookingAtScreen = !lookingAway
        
        print("📊 Gaze angle - Yaw: \(face.yaw?.doubleValue ?? 0.0), Roll: \(face.roll?.doubleValue ?? 0.0)")
        print("🎯 Looking away: \(lookingAway)")
        print("👀 User looking at screen: \(userLookingAtScreen)")
    }
    
    private func detectEyesClosed(leftEye: VNFaceLandmarkRegion2D, rightEye: VNFaceLandmarkRegion2D) -> Bool {
        guard leftEye.pointCount >= 2, rightEye.pointCount >= 2 else {
            print("⚠️ Eye landmarks insufficient for eye closure detection")
            return false
        }
        
        let leftEyeHeight = calculateEyeHeight(leftEye)
        let rightEyeHeight = calculateEyeHeight(rightEye)
        
        let closedThreshold: CGFloat = 0.02
        
        let isClosed = leftEyeHeight < closedThreshold && rightEyeHeight < closedThreshold
        
        print("👁️ Eye closure detection - Left: \(leftEyeHeight) < \(closedThreshold) = \(leftEyeHeight < closedThreshold), Right: \(rightEyeHeight) < \(closedThreshold) = \(rightEyeHeight < closedThreshold)")
        
        return isClosed
    }
    
    private func calculateEyeHeight(_ eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let points = eye.normalizedPoints
        print("📏 Eye points count: \(points.count)")
        guard points.count >= 2 else { return 0 }
        
        let yValues = points.map { $0.y }
        let maxY = yValues.max() ?? 0
        let minY = yValues.min() ?? 0
        
        let height = abs(maxY - minY)
        print("📏 Eye height calculation: max(\(maxY)) - min(\(minY)) = \(height)")
        
        return height
    }
    
    private func detectLookingAway(face: VNFaceObservation, landmarks: VNFaceLandmarks2D) -> Bool {
        let yaw = face.yaw?.doubleValue ?? 0.0
        let roll = face.roll?.doubleValue ?? 0.0
        
        let yawThreshold = 0.35
        let rollThreshold = 0.4
        
        let isLookingAway = abs(yaw) > yawThreshold || abs(roll) > rollThreshold
        
        print("📊 Gaze detection - Yaw: \(yaw), Roll: \(roll)")
        print("📉 Thresholds - Yaw: \(yawThreshold), Roll: \(rollThreshold)")
        print("🎯 Looking away result: \(isLookingAway)")
        
        return isLookingAway
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
