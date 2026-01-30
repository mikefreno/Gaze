//
//  GazeDetector.swift
//  Gaze
//
//  Gaze detection logic and pupil analysis.
//

import Foundation
@preconcurrency import Vision
import simd

struct EyeTrackingProcessingResult: Sendable {
    let faceDetected: Bool
    let isEyesClosed: Bool
    let userLookingAtScreen: Bool
    let leftPupilRatio: Double?
    let rightPupilRatio: Double?
    let leftVerticalRatio: Double?
    let rightVerticalRatio: Double?
    let yaw: Double?
    let pitch: Double?
    let faceWidthRatio: Double?
}

final class GazeDetector: @unchecked Sendable {
    struct GazeResult: Sendable {
        let isLookingAway: Bool
        let isEyesClosed: Bool
        let leftPupilRatio: Double?
        let rightPupilRatio: Double?
        let leftVerticalRatio: Double?
        let rightVerticalRatio: Double?
        let yaw: Double?
        let pitch: Double?
    }

    struct Configuration: Sendable {
        let thresholds: GazeThresholds?
        let isCalibrationComplete: Bool
        let eyeClosedEnabled: Bool
        let eyeClosedThreshold: CGFloat
        let yawEnabled: Bool
        let yawThreshold: Double
        let pitchUpEnabled: Bool
        let pitchUpThreshold: Double
        let pitchDownEnabled: Bool
        let pitchDownThreshold: Double
        let pixelGazeEnabled: Bool
        let pixelGazeMinRatio: Double
        let pixelGazeMaxRatio: Double
        let boundaryForgivenessMargin: Double
        let distanceSensitivity: Double
        let defaultReferenceFaceWidth: Double
    }

    private let lock = NSLock()
    private nonisolated(unsafe) var configuration: Configuration

    nonisolated init(configuration: Configuration) {
        self.configuration = configuration
    }

    nonisolated func updateConfiguration(_ configuration: Configuration) {
        lock.lock()
        self.configuration = configuration
        lock.unlock()
    }

    func process(
        analysis: VisionPipeline.FaceAnalysis,
        pixelBuffer: CVPixelBuffer
    ) -> EyeTrackingProcessingResult {
        let config: Configuration
        lock.lock()
        config = configuration
        lock.unlock()

        guard analysis.faceDetected, let face = analysis.face?.value else {
            return EyeTrackingProcessingResult(
                faceDetected: false,
                isEyesClosed: false,
                userLookingAtScreen: false,
                leftPupilRatio: nil,
                rightPupilRatio: nil,
                leftVerticalRatio: nil,
                rightVerticalRatio: nil,
                yaw: analysis.debugYaw,
                pitch: analysis.debugPitch,
                faceWidthRatio: nil
            )
        }

        let landmarks = face.landmarks
        let yaw = face.yaw?.doubleValue ?? 0.0
        let pitch = face.pitch?.doubleValue ?? 0.0

        var isEyesClosed = false
        if let leftEye = landmarks?.leftEye, let rightEye = landmarks?.rightEye {
            isEyesClosed = detectEyesClosed(leftEye: leftEye, rightEye: rightEye, configuration: config)
        }

        let gazeResult = detectLookingAway(
            face: face,
            landmarks: landmarks,
            imageSize: analysis.imageSize,
            pixelBuffer: pixelBuffer,
            configuration: config
        )

        let lookingAway = gazeResult.lookingAway
        let userLookingAtScreen = !lookingAway

        return EyeTrackingProcessingResult(
            faceDetected: true,
            isEyesClosed: isEyesClosed,
            userLookingAtScreen: userLookingAtScreen,
            leftPupilRatio: gazeResult.leftPupilRatio,
            rightPupilRatio: gazeResult.rightPupilRatio,
            leftVerticalRatio: gazeResult.leftVerticalRatio,
            rightVerticalRatio: gazeResult.rightVerticalRatio,
            yaw: gazeResult.yaw ?? yaw,
            pitch: gazeResult.pitch ?? pitch,
            faceWidthRatio: face.boundingBox.width
        )
    }

    private func detectEyesClosed(
        leftEye: VNFaceLandmarkRegion2D,
        rightEye: VNFaceLandmarkRegion2D,
        configuration: Configuration
    ) -> Bool {
        guard configuration.eyeClosedEnabled else { return false }
        guard leftEye.pointCount >= 2, rightEye.pointCount >= 2 else { return false }

        let leftEyeHeight = calculateEyeHeight(leftEye)
        let rightEyeHeight = calculateEyeHeight(rightEye)
        let closedThreshold = configuration.eyeClosedThreshold

        return leftEyeHeight < closedThreshold && rightEyeHeight < closedThreshold
    }

    private func calculateEyeHeight(_ eye: VNFaceLandmarkRegion2D) -> CGFloat {
        let points = eye.normalizedPoints
        guard points.count >= 2 else { return 0 }

        let yValues = points.map { $0.y }
        let maxY = yValues.max() ?? 0
        let minY = yValues.min() ?? 0

        return abs(maxY - minY)
    }

    private struct GazeDetectionResult: Sendable {
        var lookingAway: Bool = false
        var leftPupilRatio: Double?
        var rightPupilRatio: Double?
        var leftVerticalRatio: Double?
        var rightVerticalRatio: Double?
        var yaw: Double?
        var pitch: Double?
    }

    private func detectLookingAway(
        face: VNFaceObservation,
        landmarks: VNFaceLandmarks2D?,
        imageSize: CGSize,
        pixelBuffer: CVPixelBuffer,
        configuration: Configuration
    ) -> GazeDetectionResult {
        var result = GazeDetectionResult()

        let yaw = face.yaw?.doubleValue ?? 0.0
        let pitch = face.pitch?.doubleValue ?? 0.0
        result.yaw = yaw
        result.pitch = pitch

        var poseLookingAway = false

        if face.pitch != nil {
            if configuration.yawEnabled {
                let yawThreshold = configuration.yawThreshold
                if abs(yaw) > yawThreshold {
                    poseLookingAway = true
                }
            }

            if !poseLookingAway {
                var pitchLookingAway = false

                if configuration.pitchUpEnabled && pitch > configuration.pitchUpThreshold {
                    pitchLookingAway = true
                }

                if configuration.pitchDownEnabled && pitch < configuration.pitchDownThreshold {
                    pitchLookingAway = true
                }

                poseLookingAway = pitchLookingAway
            }
        }

        var eyesLookingAway = false

        if let landmarks,
           let leftEye = landmarks.leftEye,
           let rightEye = landmarks.rightEye,
           configuration.pixelGazeEnabled {
            var leftGazeRatio: Double? = nil
            var rightGazeRatio: Double? = nil
            var leftVerticalRatio: Double? = nil
            var rightVerticalRatio: Double? = nil

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
                leftVerticalRatio = calculateVerticalRatio(
                    pupilPosition: leftResult.pupilPosition,
                    eyeRegion: leftResult.eyeRegion
                )
            }

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
                rightVerticalRatio = calculateVerticalRatio(
                    pupilPosition: rightResult.pupilPosition,
                    eyeRegion: rightResult.eyeRegion
                )
            }

            result.leftPupilRatio = leftGazeRatio
            result.rightPupilRatio = rightGazeRatio
            result.leftVerticalRatio = leftVerticalRatio
            result.rightVerticalRatio = rightVerticalRatio

            if let leftRatio = leftGazeRatio,
               let rightRatio = rightGazeRatio {
                let avgH = (leftRatio + rightRatio) / 2.0
                let avgV = (leftVerticalRatio != nil && rightVerticalRatio != nil)
                    ? (leftVerticalRatio! + rightVerticalRatio!) / 2.0
                    : 0.5

                if configuration.isCalibrationComplete,
                   let thresholds = configuration.thresholds {
                    let currentFaceWidth = face.boundingBox.width
                    let refFaceWidth = thresholds.referenceFaceWidth

                    var distanceScale = 1.0
                    if refFaceWidth > 0 && currentFaceWidth > 0 {
                        let rawScale = refFaceWidth / currentFaceWidth
                        distanceScale = 1.0 + (rawScale - 1.0) * configuration.distanceSensitivity
                        distanceScale = max(0.5, min(2.0, distanceScale))
                    }

                    let centerH = (thresholds.screenLeftBound + thresholds.screenRightBound) / 2.0
                    let centerV = (thresholds.screenTopBound + thresholds.screenBottomBound) / 2.0

                    let deltaH = (avgH - centerH) * distanceScale
                    let deltaV = (avgV - centerV) * distanceScale

                    let normalizedH = centerH + deltaH
                    let normalizedV = centerV + deltaV

                    let margin = configuration.boundaryForgivenessMargin
                    let isLookingLeft = normalizedH > (thresholds.screenLeftBound + margin)
                    let isLookingRight = normalizedH < (thresholds.screenRightBound - margin)
                    let isLookingUp = normalizedV < (thresholds.screenTopBound - margin)
                    let isLookingDown = normalizedV > (thresholds.screenBottomBound + margin)

                    eyesLookingAway = isLookingLeft || isLookingRight || isLookingUp || isLookingDown
                } else {
                    let currentFaceWidth = face.boundingBox.width
                    let refFaceWidth = configuration.defaultReferenceFaceWidth

                    var distanceScale = 1.0
                    if refFaceWidth > 0 && currentFaceWidth > 0 {
                        let rawScale = refFaceWidth / currentFaceWidth
                        distanceScale = 1.0 + (rawScale - 1.0) * configuration.distanceSensitivity
                        distanceScale = max(0.5, min(2.0, distanceScale))
                    }

                    let centerH = (configuration.pixelGazeMinRatio + configuration.pixelGazeMaxRatio) / 2.0
                    let normalizedH = centerH + (avgH - centerH) * distanceScale

                    let lookingRight = normalizedH <= configuration.pixelGazeMinRatio
                    let lookingLeft = normalizedH >= configuration.pixelGazeMaxRatio
                    eyesLookingAway = lookingRight || lookingLeft
                }
            }
        }

        result.lookingAway = poseLookingAway || eyesLookingAway
        return result
    }

    private func calculateGazeRatio(
        pupilPosition: PupilPosition,
        eyeRegion: EyeRegion
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

    private func calculateVerticalRatio(
        pupilPosition: PupilPosition,
        eyeRegion: EyeRegion
    ) -> Double {
        let pupilX = Double(pupilPosition.x)
        let eyeWidth = Double(eyeRegion.frame.width)

        guard eyeWidth > 0 else { return 0.5 }

        let ratio = pupilX / eyeWidth
        return max(0.0, min(1.0, ratio))
    }
}
