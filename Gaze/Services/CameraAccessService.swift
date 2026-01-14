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
        guard #available(macOS 12.0, *) else {
            throw CameraAccessError.unsupportedOS
        }

        if isCameraAuthorized {
            return
        }

        let status = await AVCaptureDevice.requestAccess(for: .video)
        if !status {
            throw CameraAccessError.accessDenied
        }

        checkCameraAuthorizationStatus()
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
