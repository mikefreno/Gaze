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
    
    private func attachLogs() {
        let attachment = XCTAttachment(string: logLines.joined(separator: "\n"))
        attachment.name = "Test Logs"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    /// Process the outer video (looking away from screen) - should detect "looking away"
    func testOuterVideoGazeDetection() async throws {
        logLines = []
        
        let projectPath = "/Users/mike/Code/Gaze/GazeTests/video-test-outer.mp4"
        guard FileManager.default.fileExists(atPath: projectPath) else {
            XCTFail("Video file not found at: \(projectPath)")
            return
        }
        let stats = try await processVideo(at: URL(fileURLWithPath: projectPath), expectLookingAway: true)
        
        // For outer video, most frames should detect gaze outside center
        let nonCenterRatio = Double(stats.nonCenterFrames) / Double(max(1, stats.pupilDetectedFrames))
        log("🎯 OUTER video: \(String(format: "%.1f%%", nonCenterRatio * 100)) frames detected as non-center (expected: >50%)")
        log("   H-range: \(String(format: "%.3f", stats.minH)) to \(String(format: "%.3f", stats.maxH))")
        log("   V-range: \(String(format: "%.3f", stats.minV)) to \(String(format: "%.3f", stats.maxV))")
        log("   Face width: \(String(format: "%.3f", stats.avgFaceWidth)) (range: \(String(format: "%.3f", stats.minFaceWidth))-\(String(format: "%.3f", stats.maxFaceWidth)))")
        
        attachLogs()
        
        // At least 50% should be detected as non-center when looking away
        XCTAssertGreaterThan(nonCenterRatio, 0.5, "Looking away video should have >50% non-center detections. Log:\n\(logLines.joined(separator: "\n"))")
    }
    
    /// Process the inner video (looking at screen) - should detect "looking at screen"
    func testInnerVideoGazeDetection() async throws {
        logLines = []
        
        let projectPath = "/Users/mike/Code/Gaze/GazeTests/video-test-inner.mp4"
        guard FileManager.default.fileExists(atPath: projectPath) else {
            XCTFail("Video file not found at: \(projectPath)")
            return
        }
        let stats = try await processVideo(at: URL(fileURLWithPath: projectPath), expectLookingAway: false)
        
        // For inner video, most frames should detect gaze at center
        let centerRatio = Double(stats.centerFrames) / Double(max(1, stats.pupilDetectedFrames))
        log("🎯 INNER video: \(String(format: "%.1f%%", centerRatio * 100)) frames detected as center (expected: >50%)")
        log("   H-range: \(String(format: "%.3f", stats.minH)) to \(String(format: "%.3f", stats.maxH))")
        log("   V-range: \(String(format: "%.3f", stats.minV)) to \(String(format: "%.3f", stats.maxV))")
        log("   Face width: \(String(format: "%.3f", stats.avgFaceWidth)) (range: \(String(format: "%.3f", stats.minFaceWidth))-\(String(format: "%.3f", stats.maxFaceWidth)))")
        
        attachLogs()
        
        // At least 50% should be detected as center when looking at screen
        XCTAssertGreaterThan(centerRatio, 0.5, "Looking at screen video should have >50% center detections. Log:\n\(logLines.joined(separator: "\n"))")
    }
    
    struct VideoStats {
        var totalFrames = 0
        var faceDetectedFrames = 0
        var pupilDetectedFrames = 0
        var centerFrames = 0
        var nonCenterFrames = 0
        var minH = Double.greatestFiniteMagnitude
        var maxH = -Double.greatestFiniteMagnitude
        var minV = Double.greatestFiniteMagnitude
        var maxV = -Double.greatestFiniteMagnitude
        var minFaceWidth = Double.greatestFiniteMagnitude
        var maxFaceWidth = -Double.greatestFiniteMagnitude
        var totalFaceWidth = 0.0
        var faceWidthCount = 0
        
        var avgFaceWidth: Double {
            faceWidthCount > 0 ? totalFaceWidth / Double(faceWidthCount) : 0
        }
    }
    
    private func processVideo(at url: URL, expectLookingAway: Bool) async throws -> VideoStats {
        var stats = VideoStats()
        
        log("\n" + String(repeating: "=", count: 60))
        log("Processing video: \(url.lastPathComponent)")
        log("Expected behavior: \(expectLookingAway ? "LOOKING AWAY (non-center)" : "LOOKING AT SCREEN (center)")")
        log(String(repeating: "=", count: 60))
        
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        log("Duration: \(String(format: "%.2f", durationSeconds)) seconds")
        
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            XCTFail("No video track found")
            return stats
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
        
        while let sampleBuffer = trackOutput.copyNextSampleBuffer() {
            defer { 
                frameIndex += 1 
                PupilDetector.advanceFrame()
            }
            
            // Only process every Nth frame
            if frameIndex % sampleInterval != 0 {
                continue
            }
            
            stats.totalFrames += 1
            
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
            
            stats.faceDetectedFrames += 1
            
            // Track face width (bounding box width as ratio of image width)
            let faceWidth = face.boundingBox.width
            stats.minFaceWidth = min(stats.minFaceWidth, faceWidth)
            stats.maxFaceWidth = max(stats.maxFaceWidth, faceWidth)
            stats.totalFaceWidth += faceWidth
            stats.faceWidthCount += 1
            
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
                stats.pupilDetectedFrames += 1
                let avgH = (lh + rh) / 2.0
                let avgV = (lv + rv) / 2.0
                
                // Track min/max ranges
                stats.minH = min(stats.minH, avgH)
                stats.maxH = max(stats.maxH, avgH)
                stats.minV = min(stats.minV, avgV)
                stats.maxV = max(stats.maxV, avgV)
                
                let direction = GazeDirection.from(horizontal: avgH, vertical: avgV)
                if direction == .center {
                    stats.centerFrames += 1
                } else {
                    stats.nonCenterFrames += 1
                }
                log(String(format: "%5d | %5.1fs | YES  | %.2f / %.2f    | %.2f / %.2f    | %@ %@", 
                      frameIndex, timeSeconds, lh, rh, lv, rv, direction.rawValue, String(describing: direction)))
            } else {
                log(String(format: "%5d | %5.1fs | YES  | PUPIL FAIL     | PUPIL FAIL     | -", frameIndex, timeSeconds))
            }
        }
        
        log(String(repeating: "=", count: 75))
        log("Summary: \(stats.totalFrames) frames sampled, \(stats.faceDetectedFrames) with face, \(stats.pupilDetectedFrames) with pupils")
        log("Center frames: \(stats.centerFrames), Non-center: \(stats.nonCenterFrames)")
        log("Face width: avg=\(String(format: "%.3f", stats.avgFaceWidth)), range=\(String(format: "%.3f", stats.minFaceWidth)) to \(String(format: "%.3f", stats.maxFaceWidth))")
        log("Processing complete\n")
        
        return stats
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
