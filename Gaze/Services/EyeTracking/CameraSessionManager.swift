//
//  CameraSessionManager.swift
//  Gaze
//
//  Manages AVCaptureSession lifecycle for eye tracking.
//

import AVFoundation
import Combine
import Foundation

protocol CameraSessionDelegate: AnyObject {
    @MainActor func cameraSession(
        _ manager: CameraSessionManager,
        didOutput pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    )
}

private struct PixelBufferBox: @unchecked Sendable {
    let buffer: CVPixelBuffer
}

final class CameraSessionManager: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    nonisolated(unsafe) weak var delegate: CameraSessionDelegate?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let videoDataOutputQueue = DispatchQueue(
        label: "com.gaze.videoDataOutput",
        qos: .userInitiated
    )
    private var _previewLayer: AVCaptureVideoPreviewLayer?

    var previewLayer: AVCaptureVideoPreviewLayer? {
        guard let session = captureSession else {
            _previewLayer = nil
            return nil
        }

        if let existing = _previewLayer, existing.session === session {
            return existing
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        _previewLayer = layer
        return layer
    }

    func start() async throws {
        guard !isRunning else { return }

        let cameraService = CameraAccessService.shared
        if !cameraService.isCameraAuthorized {
            try await cameraService.requestCameraAccess()
        }

        guard cameraService.isCameraAuthorized else {
            throw CameraAccessError.accessDenied
        }

        try setupCaptureSession()
        captureSession?.startRunning()
        isRunning = true
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        _previewLayer = nil
        isRunning = false
    }

    private func setupCaptureSession() throws {
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

        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }

        self.captureSession = session
        self.videoOutput = output
    }
}

extension CameraSessionManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let size = CGSize(
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer)
        )

        let bufferBox = PixelBufferBox(buffer: pixelBuffer)

        DispatchQueue.main.async { [weak self, bufferBox] in
            guard let self else { return }
            self.delegate?.cameraSession(self, didOutput: bufferBox.buffer, imageSize: size)
        }
    }
}
