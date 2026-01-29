//
//  CalibrationSampleCollector.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import Foundation

struct CalibrationSampleCollector {
    mutating func addSample(
        to data: inout CalibrationData,
        step: CalibrationStep,
        leftRatio: Double?,
        rightRatio: Double?,
        leftVertical: Double?,
        rightVertical: Double?,
        faceWidthRatio: Double?
    ) {
        let sample = GazeSample(
            leftRatio: leftRatio,
            rightRatio: rightRatio,
            leftVerticalRatio: leftVertical,
            rightVerticalRatio: rightVertical,
            faceWidthRatio: faceWidthRatio
        )
        data.addSample(sample, for: step)
    }
}
