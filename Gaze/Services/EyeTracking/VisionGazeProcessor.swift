//
//  VisionGazeProcessor.swift
//  Gaze
//
//  Created by Mike Freno on 1/31/26.
//

import Foundation
@preconcurrency import Vision

final class VisionGazeProcessor: @unchecked Sendable {
    struct EyeObservation: Sendable {
        let center: CGPoint
        let width: Double
        let height: Double
        let pupil: CGPoint?
        let frame: CGRect
        let normalizedPupil: CGPoint?
        let hasPupilLandmarks: Bool
    }

    struct ObservationResult: Sendable {
        let faceDetected: Bool
        let eyesClosed: Bool
        let gazeState: GazeState
        let confidence: Double
        let horizontal: Double?
        let vertical: Double?
        let debugState: EyeTrackingDebugState
    }

    private let baselineModel = GazeBaselineModel()
    private var config: TrackingConfig

    init(config: TrackingConfig) {
        self.config = config
    }

    func updateConfig(_ config: TrackingConfig) {
        self.config = config
    }

    func resetBaseline() {
        baselineModel.reset()
    }

    func process(analysis: VisionPipeline.FaceAnalysis) -> ObservationResult {
        guard analysis.faceDetected, let face = analysis.face?.value else {
            return ObservationResult(
                faceDetected: false,
                eyesClosed: false,
                gazeState: .unknown,
                confidence: 0,
                horizontal: nil,
                vertical: nil,
                debugState: .empty
            )
        }

        guard let landmarks = face.landmarks else {
            return ObservationResult(
                faceDetected: true,
                eyesClosed: false,
                gazeState: .unknown,
                confidence: 0.3,
                horizontal: nil,
                vertical: nil,
                debugState: .empty
            )
        }

        let leftEye = makeEyeObservation(
            eye: landmarks.leftEye,
            pupil: landmarks.leftPupil,
            face: face,
            imageSize: analysis.imageSize
        )
        let rightEye = makeEyeObservation(
            eye: landmarks.rightEye,
            pupil: landmarks.rightPupil,
            face: face,
            imageSize: analysis.imageSize
        )

        let eyesClosed = detectEyesClosed(left: leftEye, right: rightEye)
        let (horizontal, vertical) = normalizePupilPosition(left: leftEye, right: rightEye)

        let confidence = calculateConfidence(leftEye: leftEye, rightEye: rightEye)
        let gazeState = decideGazeState(
            horizontal: horizontal,
            vertical: vertical,
            confidence: confidence,
            eyesClosed: eyesClosed
        )

        let debugState = EyeTrackingDebugState(
            leftEyeRect: leftEye?.frame,
            rightEyeRect: rightEye?.frame,
            leftPupil: leftEye?.pupil,
            rightPupil: rightEye?.pupil,
            imageSize: analysis.imageSize
        )

        return ObservationResult(
            faceDetected: true,
            eyesClosed: eyesClosed,
            gazeState: gazeState,
            confidence: confidence,
            horizontal: horizontal,
            vertical: vertical,
            debugState: debugState
        )
    }

    private func makeEyeObservation(
        eye: VNFaceLandmarkRegion2D?,
        pupil: VNFaceLandmarkRegion2D?,
        face: VNFaceObservation,
        imageSize: CGSize
    ) -> EyeObservation? {
        guard let eye else { return nil }

        let eyePoints = normalizePoints(eye.normalizedPoints, face: face, imageSize: imageSize)
        guard let bounds = boundingRect(points: eyePoints) else { return nil }

        let pupilPoint: CGPoint?
        let hasPupilLandmarks = (pupil?.pointCount ?? 0) > 0
        if let pupil, pupil.pointCount > 0 {
            let pupilPoints = normalizePoints(pupil.normalizedPoints, face: face, imageSize: imageSize)
            pupilPoint = averagePoint(pupilPoints, fallback: bounds.center)
        } else {
            pupilPoint = bounds.center
        }

        let normalizedPupil: CGPoint?
        if let pupilPoint {
            let nx = clamp((pupilPoint.x - bounds.minX) / bounds.size.width)
            let ny = clamp((pupilPoint.y - bounds.minY) / bounds.size.height)
            normalizedPupil = CGPoint(x: nx, y: ny)
        } else {
            normalizedPupil = nil
        }

        return EyeObservation(
            center: bounds.center,
            width: bounds.size.width,
            height: bounds.size.height,
            pupil: pupilPoint,
            frame: CGRect(x: bounds.minX, y: bounds.minY, width: bounds.size.width, height: bounds.size.height),
            normalizedPupil: normalizedPupil,
            hasPupilLandmarks: hasPupilLandmarks
        )
    }

    private func normalizePoints(
        _ points: [CGPoint],
        face: VNFaceObservation,
        imageSize: CGSize
    ) -> [CGPoint] {
        points.map { point in
            let x = (face.boundingBox.origin.x + point.x * face.boundingBox.size.width)
                * imageSize.width
            let y = (1.0 - (face.boundingBox.origin.y + point.y * face.boundingBox.size.height))
                * imageSize.height
            return CGPoint(x: x, y: y)
        }
    }

    private func boundingRect(points: [CGPoint]) -> (center: CGPoint, size: CGSize, minX: CGFloat, minY: CGFloat)? {
        guard !points.isEmpty else { return nil }
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        let width = maxX - minX
        let height = maxY - minY
        guard width > 0, height > 0 else { return nil }

        return (
            center: CGPoint(x: minX + width / 2, y: minY + height / 2),
            size: CGSize(width: width, height: height),
            minX: minX,
            minY: minY
        )
    }

    private func averagePoint(_ points: [CGPoint], fallback: CGPoint) -> CGPoint {
        guard !points.isEmpty else { return fallback }
        let sum = points.reduce(CGPoint.zero) { partial, next in
            CGPoint(x: partial.x + next.x, y: partial.y + next.y)
        }
        return CGPoint(x: sum.x / CGFloat(points.count), y: sum.y / CGFloat(points.count))
    }

    private func clamp(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }

    private func averageCoordinate(left: CGFloat?, right: CGFloat?, fallback: Double?) -> Double? {
        switch (left, right) {
        case let (left?, right?):
            return Double((left + right) / 2)
        case let (left?, nil):
            return Double(left)
        case let (nil, right?):
            return Double(right)
        default:
            return fallback
        }
    }

    private func normalizePupilPosition(
        left: EyeObservation?,
        right: EyeObservation?
    ) -> (horizontal: Double?, vertical: Double?) {
        let leftPupil = left?.normalizedPupil
        let rightPupil = right?.normalizedPupil

        let horizontal = averageCoordinate(
            left: leftPupil?.x,
            right: rightPupil?.x,
            fallback: nil
        )
        let vertical = averageCoordinate(
            left: leftPupil?.y,
            right: rightPupil?.y,
            fallback: nil
        )
        return (horizontal, vertical)
    }

    private func detectEyesClosed(left: EyeObservation?, right: EyeObservation?) -> Bool {
        guard let left, let right else { return false }
        let leftRatio = left.height / max(left.width, 1)
        let rightRatio = right.height / max(right.width, 1)
        let avgRatio = (leftRatio + rightRatio) / 2
        return avgRatio < config.eyeClosedThreshold
    }

    private func calculateConfidence(leftEye: EyeObservation?, rightEye: EyeObservation?) -> Double {
        var score = 0.0
        if leftEye?.hasPupilLandmarks == true { score += 0.35 }
        if rightEye?.hasPupilLandmarks == true { score += 0.35 }
        if leftEye != nil { score += 0.15 }
        if rightEye != nil { score += 0.15 }
        return min(1.0, score)
    }

    private func decideGazeState(
        horizontal: Double?,
        vertical: Double?,
        confidence: Double,
        eyesClosed: Bool
    ) -> GazeState {
        guard confidence >= config.minConfidence else { return .unknown }
        guard let horizontal, let vertical else { return .unknown }
        if eyesClosed { return .unknown }

        let baseline = baselineModel.current(
            defaultH: config.defaultCenterHorizontal,
            defaultV: config.defaultCenterVertical
        )

        let deltaH = abs(horizontal - baseline.horizontal)
        let deltaV = abs(vertical - baseline.vertical)
        let away = deltaH > config.horizontalAwayThreshold || deltaV > config.verticalAwayThreshold

        if config.baselineEnabled {
            if baseline.sampleCount < config.minBaselineSamples {
                baselineModel.update(
                    horizontal: horizontal,
                    vertical: vertical,
                    smoothing: config.baselineSmoothing
                )
            } else if deltaH < config.baselineUpdateThreshold
                && deltaV < config.baselineUpdateThreshold {
                baselineModel.update(
                    horizontal: horizontal,
                    vertical: vertical,
                    smoothing: config.baselineSmoothing
                )
            }
        }

        let stable = baseline.sampleCount >= config.minBaselineSamples || !config.baselineEnabled
        if !stable { return .unknown }
        return away ? .lookingAway : .lookingAtScreen
    }
}
