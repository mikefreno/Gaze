//
//  EyeDebugStateAdapter.swift
//  Gaze
//
//  Debug state storage for eye tracking UI.
//

import AppKit
import Foundation

@MainActor
final class EyeDebugStateAdapter {
    var leftPupilRatio: Double?
    var rightPupilRatio: Double?
    var leftVerticalRatio: Double?
    var rightVerticalRatio: Double?
    var yaw: Double?
    var pitch: Double?
    var enableDebugLogging: Bool = false {
        didSet {
            PupilDetector.enableDiagnosticLogging = enableDebugLogging
        }
    }

    var leftEyeInput: NSImage?
    var rightEyeInput: NSImage?
    var leftEyeProcessed: NSImage?
    var rightEyeProcessed: NSImage?
    var leftPupilPosition: PupilPosition?
    var rightPupilPosition: PupilPosition?
    var leftEyeSize: CGSize?
    var rightEyeSize: CGSize?
    var leftEyeRegion: EyeRegion?
    var rightEyeRegion: EyeRegion?
    var imageSize: CGSize?

    var gazeDirection: GazeDirection {
        guard let leftH = leftPupilRatio,
              let rightH = rightPupilRatio,
              let leftV = leftVerticalRatio,
              let rightV = rightVerticalRatio else {
            return .center
        }

        let avgHorizontal = (leftH + rightH) / 2.0
        let avgVertical = (leftV + rightV) / 2.0

        return GazeDirection.from(horizontal: avgHorizontal, vertical: avgVertical)
    }

    func update(from result: EyeTrackingProcessingResult) {
        leftPupilRatio = result.leftPupilRatio
        rightPupilRatio = result.rightPupilRatio
        leftVerticalRatio = result.leftVerticalRatio
        rightVerticalRatio = result.rightVerticalRatio
        yaw = result.yaw
        pitch = result.pitch
    }

    func updateEyeImages(from detector: PupilDetector.Type) {
        if let leftInput = detector.debugLeftEyeInput {
            leftEyeInput = NSImage(cgImage: leftInput, size: NSSize(width: leftInput.width, height: leftInput.height))
        }
        if let rightInput = detector.debugRightEyeInput {
            rightEyeInput = NSImage(cgImage: rightInput, size: NSSize(width: rightInput.width, height: rightInput.height))
        }
        if let leftProcessed = detector.debugLeftEyeProcessed {
            leftEyeProcessed = NSImage(cgImage: leftProcessed, size: NSSize(width: leftProcessed.width, height: leftProcessed.height))
        }
        if let rightProcessed = detector.debugRightEyeProcessed {
            rightEyeProcessed = NSImage(cgImage: rightProcessed, size: NSSize(width: rightProcessed.width, height: rightProcessed.height))
        }
        leftPupilPosition = detector.debugLeftPupilPosition
        rightPupilPosition = detector.debugRightPupilPosition
        leftEyeSize = detector.debugLeftEyeSize
        rightEyeSize = detector.debugRightEyeSize
        leftEyeRegion = detector.debugLeftEyeRegion
        rightEyeRegion = detector.debugRightEyeRegion
        imageSize = detector.debugImageSize
    }

    func clear() {
        leftPupilRatio = nil
        rightPupilRatio = nil
        leftVerticalRatio = nil
        rightVerticalRatio = nil
        yaw = nil
        pitch = nil
        leftEyeInput = nil
        rightEyeInput = nil
        leftEyeProcessed = nil
        rightEyeProcessed = nil
        leftPupilPosition = nil
        rightPupilPosition = nil
        leftEyeSize = nil
        rightEyeSize = nil
        leftEyeRegion = nil
        rightEyeRegion = nil
        imageSize = nil
    }
}
