//
//  VideoGazeTests.swift
//  GazeTests
//
//  Created by Claude on 1/16/26.
//

import XCTest
import AVFoundation
import Vision
@testable import Gaze

final class VideoGazeTests: XCTestCase {
    
    var logLines: [String] = []
    
    private func log(_ message: String) {
        logLines.append(message)
    }
    
    /// Process the outer video and log gaze detection results
    func testOuterVideoGazeDetection() async throws {
        logLines = []
        
        let projectPath = "/Users/mike/Code/Gaze/GazeTests/video-test-outer.mp4"
        guard FileManager.default.fileExists(atPath: projectPath) else {
            XCTFail("Video file not found at: \(projectPath)")
            return
        }
        try await processVideo(at: URL(fileURLWithPath: projectPath))
    }
    
    /// Process the inner video and log gaze detection results
    func testInnerVideoGazeDetection() async throws {
        logLines = []
        
        let projectPath = "/Users/mike/Code/Gaze/GazeTests/video-test-inner.mp4"
        guard FileManager.default.fileExists(atPath: projectPath) else {
            XCTFail("Video file not found at: \(projectPath)")
            return
        }
        try await processVideo(at: URL(fileURLWithPath: projectPath))
    }
    
    private func processVideo(at url: URL) async throws {
        log("\n" + String(repeating: "=", count: 60))
        log("Processing video: \(url.lastPathComponent)")
        log(String(repeating: "=", count: 60))
        
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        log("Duration: \(String(format: "%.2f", durationSeconds)) seconds")
        
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            XCTFail("No video track found")
            return
        }
        
        let size = try await track.load(.naturalSize)
        let frameRate = try await track.load(.nominalFrameRate)
        log("Size: \(Int(size.width))x\(Int(size.height)), FPS: \(String(format: "%.1f", frameRate))")
        
        let reader = try AVAssetReader(asset: asset)
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let trackOutput = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        reader.add(trackOutput)
        reader.startReading()
        
        var frameIndex = 0
        let sampleInterval = max(1, Int(frameRate / 2)) // Sample ~2 frames per second
        
        log("\nFrame | Time  | Face | H-Ratio L/R    | V-Ratio L/R    | Direction")
        log(String(repeating: "-", count: 75))
        
        // Reset calibration for fresh test
        PupilDetector.calibration.reset()
        
        // Disable frame skipping for video testing
        let originalFrameSkip = PupilDetector.frameSkipCount
        PupilDetector.frameSkipCount = 1
        defer { PupilDetector.frameSkipCount = originalFrameSkip }
        
        var totalFrames = 0
        var faceDetectedFrames = 0
        var pupilDetectedFrames = 0
        
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            defer { 
                frameIndex += 1 
                PupilDetector.advanceFrame()
            }
            
            // Only process every Nth frame
            if frameIndex % sampleInterval != 0 {
                continue
            }
            
            totalFrames += 1
            
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }
            
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let timeSeconds = CMTimeGetSeconds(timestamp)
            
            // Run face detection
            let request = VNDetectFaceLandmarksRequest()
            request.revision = VNDetectFaceLandmarksRequestRevision3
            
            let handler = VNImageRequestHandler(
                cvPixelBuffer: pixelBuffer,
                orientation: .leftMirrored,
                options: [:]
            )
            
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty,
                  let face = observations.first,
                  let landmarks = face.landmarks,
                  let leftEye = landmarks.leftEye,
                  let rightEye = landmarks.rightEye else {
                log(String(format: "%5d | %5.1fs | NO   | -              | -              | -", frameIndex, timeSeconds))
                continue
            }
            
            faceDetectedFrames += 1
            
            let imageSize = CGSize(
                width: CVPixelBufferGetWidth(pixelBuffer),
                height: CVPixelBufferGetHeight(pixelBuffer)
            )
            
            // Detect pupils
            var leftHRatio: Double?
            var rightHRatio: Double?
            var leftVRatio: Double?
            var rightVRatio: Double?
            
            if let leftResult = PupilDetector.detectPupil(
                in: pixelBuffer,
                eyeLandmarks: leftEye,
                faceBoundingBox: face.boundingBox,
                imageSize: imageSize,
                side: 0
            ) {
                leftHRatio = calculateHorizontalRatio(pupilPosition: leftResult.pupilPosition, eyeRegion: leftResult.eyeRegion)
                leftVRatio = calculateVerticalRatio(pupilPosition: leftResult.pupilPosition, eyeRegion: leftResult.eyeRegion)
            }
            
            if let rightResult = PupilDetector.detectPupil(
                in: pixelBuffer,
                eyeLandmarks: rightEye,
                faceBoundingBox: face.boundingBox,
                imageSize: imageSize,
                side: 1
            ) {
                rightHRatio = calculateHorizontalRatio(pupilPosition: rightResult.pupilPosition, eyeRegion: rightResult.eyeRegion)
                rightVRatio = calculateVerticalRatio(pupilPosition: rightResult.pupilPosition, eyeRegion: rightResult.eyeRegion)
            }
            
            if let lh = leftHRatio, let rh = rightHRatio,
               let lv = leftVRatio, let rv = rightVRatio {
                pupilDetectedFrames += 1
                let avgH = (lh + rh) / 2.0
                let avgV = (lv + rv) / 2.0
                let direction = GazeDirection.from(horizontal: avgH, vertical: avgV)
                log(String(format: "%5d | %5.1fs | YES  | %.2f / %.2f    | %.2f / %.2f    | %@ %@", 
                      frameIndex, timeSeconds, lh, rh, lv, rv, direction.rawValue, String(describing: direction)))
            } else {
                log(String(format: "%5d | %5.1fs | YES  | PUPIL FAIL     | PUPIL FAIL     | -", frameIndex, timeSeconds))
            }
        }
        
        log(String(repeating: "=", count: 75))
        log("Summary: \(totalFrames) frames sampled, \(faceDetectedFrames) with face, \(pupilDetectedFrames) with pupils")
        log("Processing complete\n")
    }
    
    private func calculateHorizontalRatio(pupilPosition: PupilPosition, eyeRegion: EyeRegion) -> Double {
        // pupilPosition.y controls horizontal gaze due to image orientation
        let pupilY = Double(pupilPosition.y)
        let eyeHeight = Double(eyeRegion.frame.height)
        
        guard eyeHeight > 0 else { return 0.5 }
        
        let ratio = pupilY / eyeHeight
        return max(0.0, min(1.0, ratio))
    }
    
    private func calculateVerticalRatio(pupilPosition: PupilPosition, eyeRegion: EyeRegion) -> Double {
        // pupilPosition.x controls vertical gaze due to image orientation
        let pupilX = Double(pupilPosition.x)
        let eyeWidth = Double(eyeRegion.frame.width)
        
        guard eyeWidth > 0 else { return 0.5 }
        
        let ratio = pupilX / eyeWidth
        return max(0.0, min(1.0, ratio))
    }
}
