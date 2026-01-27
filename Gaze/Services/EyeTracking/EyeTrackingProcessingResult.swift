//
//  EyeTrackingProcessingResult.swift
//  Gaze
//
//  Shared processing result for eye tracking pipeline.
//

import Foundation

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
