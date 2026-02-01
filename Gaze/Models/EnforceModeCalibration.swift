//
//  EnforceModeCalibration.swift
//  Gaze
//
//  Created by Mike Freno on 2/1/26.
//

import Foundation

struct EnforceModeCalibration: Codable, Equatable, Hashable, Sendable {
    let createdAt: Date
    let eyeBoxWidthFactor: Double
    let eyeBoxHeightFactor: Double
    let faceWidthRatio: Double
    let horizontalMin: Double
    let horizontalMax: Double
    let verticalMin: Double
    let verticalMax: Double
}
