//
//  CalibrationThresholdCalculator.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import Foundation

struct CalibrationThresholdCalculator {
    func calculate(using data: CalibrationData) -> GazeThresholds? {
        let centerH = data.averageRatio(for: .center)
        let centerV = data.averageVerticalRatio(for: .center)

        guard let cH = centerH else {
            print("⚠️ No center calibration data, using defaults")
            return GazeThresholds.defaultThresholds
        }

        let cV = centerV ?? 0.45

        print("📊 Calibration data collected:")
        print("  Center H: \(String(format: "%.3f", cH)), V: \(String(format: "%.3f", cV))")

        let screenLeftH = data.averageRatio(for: .left)
            ?? data.averageRatio(for: .topLeft)
            ?? data.averageRatio(for: .bottomLeft)
        let screenRightH = data.averageRatio(for: .right)
            ?? data.averageRatio(for: .topRight)
            ?? data.averageRatio(for: .bottomRight)

        let farLeftH = data.averageRatio(for: .farLeft)
        let farRightH = data.averageRatio(for: .farRight)

        let (leftBound, lookLeftThreshold) = horizontalBounds(
            center: cH,
            screenEdge: screenLeftH,
            farEdge: farLeftH,
            direction: .left
        )
        let (rightBound, lookRightThreshold) = horizontalBounds(
            center: cH,
            screenEdge: screenRightH,
            farEdge: farRightH,
            direction: .right
        )

        let screenTopV = data.averageVerticalRatio(for: .up)
            ?? data.averageVerticalRatio(for: .topLeft)
            ?? data.averageVerticalRatio(for: .topRight)
        let screenBottomV = data.averageVerticalRatio(for: .down)
            ?? data.averageVerticalRatio(for: .bottomLeft)
            ?? data.averageVerticalRatio(for: .bottomRight)

        let (topBound, lookUpThreshold) = verticalBounds(center: cV, screenEdge: screenTopV, isUpperEdge: true)
        let (bottomBound, lookDownThreshold) = verticalBounds(
            center: cV,
            screenEdge: screenBottomV,
            isUpperEdge: false
        )

        let allFaceWidths = CalibrationStep.allCases.compactMap { data.averageFaceWidth(for: $0) }
        let refFaceWidth = allFaceWidths.isEmpty ? 0.0 : allFaceWidths.average()

        let thresholds = GazeThresholds(
            minLeftRatio: lookLeftThreshold,
            maxRightRatio: lookRightThreshold,
            minUpRatio: lookUpThreshold,
            maxDownRatio: lookDownThreshold,
            screenLeftBound: leftBound,
            screenRightBound: rightBound,
            screenTopBound: topBound,
            screenBottomBound: bottomBound,
            referenceFaceWidth: refFaceWidth
        )

        logThresholds(
            thresholds: thresholds,
            centerHorizontal: cH,
            centerVertical: cV
        )

        return thresholds
    }

    private enum HorizontalDirection {
        case left
        case right
    }

    private func horizontalBounds(
        center: Double,
        screenEdge: Double?,
        farEdge: Double?,
        direction: HorizontalDirection
    ) -> (bound: Double, threshold: Double) {
        let defaultBoundOffset = direction == .left ? 0.15 : -0.15
        let defaultThresholdOffset = direction == .left ? 0.20 : -0.20

        guard let screenEdge = screenEdge else {
            return (center + defaultBoundOffset, center + defaultThresholdOffset)
        }

        let bound = screenEdge
        let threshold: Double
        if let farEdge = farEdge {
            threshold = (screenEdge + farEdge) / 2.0
        } else {
            threshold = screenEdge + defaultThresholdOffset
        }

        return (bound, threshold)
    }

    private func verticalBounds(center: Double, screenEdge: Double?, isUpperEdge: Bool) -> (bound: Double, threshold: Double) {
        let defaultBoundOffset = isUpperEdge ? -0.10 : 0.10
        let defaultThresholdOffset = isUpperEdge ? -0.15 : 0.15

        guard let screenEdge = screenEdge else {
            return (center + defaultBoundOffset, center + defaultThresholdOffset)
        }

        let bound = screenEdge
        let edgeDistance = isUpperEdge ? center - screenEdge : screenEdge - center
        let threshold = isUpperEdge ? screenEdge - (edgeDistance * 0.5) : screenEdge + (edgeDistance * 0.5)

        return (bound, threshold)
    }

    private func logThresholds(
        thresholds: GazeThresholds,
        centerHorizontal: Double,
        centerVertical: Double
    ) {
        print("✓ Calibration thresholds calculated:")
        print("  Center: H=\(String(format: "%.3f", centerHorizontal)), V=\(String(format: "%.3f", centerVertical))")
        print(
            "  Screen H-Range: \(String(format: "%.3f", thresholds.screenRightBound)) to \(String(format: "%.3f", thresholds.screenLeftBound))"
        )
        print(
            "  Screen V-Range: \(String(format: "%.3f", thresholds.screenTopBound)) to \(String(format: "%.3f", thresholds.screenBottomBound))"
        )
        print(
            "  Away Thresholds: L≥\(String(format: "%.3f", thresholds.minLeftRatio)), R≤\(String(format: "%.3f", thresholds.maxRightRatio))"
        )
        print(
            "  Away Thresholds: U≤\(String(format: "%.3f", thresholds.minUpRatio)), D≥\(String(format: "%.3f", thresholds.maxDownRatio))"
        )
        print("  Ref Face Width: \(String(format: "%.3f", thresholds.referenceFaceWidth))")
    }
}

private extension Array where Element == Double {
    func average() -> Double {
        guard !isEmpty else { return 0 }
        return reduce(0.0, +) / Double(count)
    }
}
