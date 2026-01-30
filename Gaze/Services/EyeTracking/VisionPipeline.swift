//
//  VisionPipeline.swift
//  Gaze
//
//  Vision processing pipeline for face detection.
//

import Foundation
@preconcurrency import Vision

final class VisionPipeline: @unchecked Sendable {
    struct FaceAnalysis: Sendable {
        let faceDetected: Bool
        let face: NonSendableFaceObservation?
        let imageSize: CGSize
        let debugYaw: Double?
        let debugPitch: Double?
    }

    struct NonSendableFaceObservation: @unchecked Sendable {
        nonisolated(unsafe) let value: VNFaceObservation
    }

    nonisolated func analyze(
        pixelBuffer: CVPixelBuffer,
        imageSize: CGSize
    ) -> FaceAnalysis {
        let request = VNDetectFaceLandmarksRequest()
        request.revision = VNDetectFaceLandmarksRequestRevision3

        if #available(macOS 14.0, *) {
            request.constellation = .constellation76Points
        }

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .upMirrored,
            options: [:]
        )

        do {
            try handler.perform([request])
        } catch {
            return FaceAnalysis(
                faceDetected: false,
                face: nil,
                imageSize: imageSize,
                debugYaw: nil,
                debugPitch: nil
            )
        }

        guard let face = request.results?.first else {
            return FaceAnalysis(
                faceDetected: false,
                face: nil,
                imageSize: imageSize,
                debugYaw: nil,
                debugPitch: nil
            )
        }

        return FaceAnalysis(
            faceDetected: true,
            face: NonSendableFaceObservation(value: face),
            imageSize: imageSize,
            debugYaw: face.yaw?.doubleValue,
            debugPitch: face.pitch?.doubleValue
        )
    }
}
