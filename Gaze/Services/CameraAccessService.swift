//
//  CameraAccessService.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import Combine

@MainActor
class CameraAccessService: ObservableObject {
    static let shared = CameraAccessService()

    @Published var isCameraAuthorized = false
    @Published var cameraError: Error?

    private init() {
        checkCameraAuthorizationStatus()
    }

    func requestCameraAccess() async throws {
        print("🎥 Requesting camera access...")
        
        guard #available(macOS 12.0, *) else {
            print("⚠️ macOS version too old")
            throw CameraAccessError.unsupportedOS
        }

        if isCameraAuthorized {
            print("✓ Camera already authorized")
            return
        }

        print("🎥 Calling AVCaptureDevice.requestAccess...")
        let status = await AVCaptureDevice.requestAccess(for: .video)
        print("🎥 Permission result: \(status)")
        
        if !status {
            throw CameraAccessError.accessDenied
        }

        checkCameraAuthorizationStatus()
        print("✓ Camera access granted")
    }

    func checkCameraAuthorizationStatus() {
        guard #available(macOS 12.0, *) else {
            isCameraAuthorized = false
            return
        }

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            isCameraAuthorized = true
            cameraError = nil
        case .notDetermined:
            isCameraAuthorized = false
            cameraError = nil
        case .denied, .restricted:
            isCameraAuthorized = false
            cameraError = CameraAccessError.accessDenied
        default:
            isCameraAuthorized = false
            cameraError = CameraAccessError.unknown
        }
    }
    
    // New method to check if face detection is supported and available
    func isFaceDetectionAvailable() -> Bool {
        // On macOS, face detection requires specific Vision framework support
        // For now we'll assume it's available if camera is authorized
        return isCameraAuthorized
    }
}

// MARK: - Error Handling

enum CameraAccessError: Error, LocalizedError {
    case accessDenied
    case unsupportedOS
    case unknown

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return
                "Camera access was denied. Please enable camera permissions in System Preferences."
        case .unsupportedOS:
            return "This feature requires macOS 12 or later."
        case .unknown:
            return "An unknown error occurred with camera access."
        }
    }
}
