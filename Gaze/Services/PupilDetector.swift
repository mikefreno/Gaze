//
//  PupilDetector.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//
//  Pixel-based pupil detection translated from Python GazeTracking library
//  Original: https://github.com/antoinelame/GazeTracking
//

import CoreImage
import Vision
import Accelerate

struct PupilPosition {
    let x: CGFloat
    let y: CGFloat
}

struct EyeRegion {
    let frame: CGRect  // Bounding box of the eye in image coordinates
    let center: CGPoint  // Center point of the eye region
}

class PupilDetector {
    
    /// Detects pupil position within an isolated eye region using pixel-based analysis
    /// - Parameters:
    ///   - pixelBuffer: The camera frame pixel buffer
    ///   - eyeLandmarks: Vision eye landmarks (6 points around iris)
    ///   - faceBoundingBox: Face bounding box from Vision
    ///   - imageSize: Size of the camera frame
    /// - Returns: Pupil position relative to eye region, or nil if detection fails
    static func detectPupil(
        in pixelBuffer: CVPixelBuffer,
        eyeLandmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> (pupilPosition: PupilPosition, eyeRegion: EyeRegion)? {
        
        // Step 1: Convert Vision landmarks to pixel coordinates
        let eyePoints = landmarksToPixelCoordinates(
            landmarks: eyeLandmarks,
            faceBoundingBox: faceBoundingBox,
            imageSize: imageSize
        )
        
        guard eyePoints.count >= 6 else { return nil }
        
        // Step 2: Create eye region bounding box
        guard let eyeRegion = createEyeRegion(from: eyePoints, imageSize: imageSize) else {
            return nil
        }
        
        // Step 3: Extract and process eye region from pixel buffer
        guard let eyeImage = extractEyeRegion(
            from: pixelBuffer,
            region: eyeRegion.frame,
            mask: eyePoints
        ) else {
            return nil
        }
        
        // Step 4: Process image to isolate pupil (bilateral filter + threshold)
        guard let processedImage = processEyeImage(eyeImage) else {
            return nil
        }
        
        // Step 5: Find pupil using contour detection
        guard let pupilPosition = findPupilCentroid(in: processedImage) else {
            return nil
        }
        
        return (pupilPosition, eyeRegion)
    }
    
    // MARK: - Step 1: Convert Landmarks to Pixel Coordinates
    
    private static func landmarksToPixelCoordinates(
        landmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> [CGPoint] {
        return landmarks.normalizedPoints.map { point in
            // Vision coordinates are normalized to face bounding box
            let imageX = (faceBoundingBox.origin.x + point.x * faceBoundingBox.width) * imageSize.width
            let imageY = (faceBoundingBox.origin.y + point.y * faceBoundingBox.height) * imageSize.height
            return CGPoint(x: imageX, y: imageY)
        }
    }
    
    // MARK: - Step 2: Create Eye Region
    
    private static func createEyeRegion(from points: [CGPoint], imageSize: CGSize) -> EyeRegion? {
        guard !points.isEmpty else { return nil }
        
        let margin: CGFloat = 5
        let minX = points.map { $0.x }.min()! - margin
        let maxX = points.map { $0.x }.max()! + margin
        let minY = points.map { $0.y }.min()! - margin
        let maxY = points.map { $0.y }.max()! + margin
        
        // Clamp to image bounds
        let clampedMinX = max(0, minX)
        let clampedMaxX = min(imageSize.width, maxX)
        let clampedMinY = max(0, minY)
        let clampedMaxY = min(imageSize.height, maxY)
        
        let frame = CGRect(
            x: clampedMinX,
            y: clampedMinY,
            width: clampedMaxX - clampedMinX,
            height: clampedMaxY - clampedMinY
        )
        
        let center = CGPoint(
            x: frame.width / 2,
            y: frame.height / 2
        )
        
        return EyeRegion(frame: frame, center: center)
    }
    
    // MARK: - Step 3: Extract Eye Region
    
    private static func extractEyeRegion(
        from pixelBuffer: CVPixelBuffer,
        region: CGRect,
        mask: [CGPoint]
    ) -> CIImage? {
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Convert to grayscale
        let grayscaleImage = ciImage.applyingFilter("CIPhotoEffectNoir")
        
        // Crop to eye region
        let croppedImage = grayscaleImage.cropped(to: region)
        
        return croppedImage
    }
    
    // MARK: - Step 4: Process Eye Image
    
    private static func processEyeImage(_ image: CIImage) -> CIImage? {
        // Apply bilateral filter (preserves edges while smoothing)
        // CIBilateralFilter approximation: use CIMedianFilter + morphology
        var processed = image
        
        // 1. Median filter (reduces noise while preserving edges)
        processed = processed.applyingFilter("CIMedianFilter")
        
        // 2. Morphological erosion (makes dark regions larger - approximates cv2.erode)
        // Use CIMorphologyMinimum with small radius
        processed = processed.applyingFilter("CIMorphologyMinimum", parameters: [
            kCIInputRadiusKey: 2.0
        ])
        
        // 3. Threshold to binary (black/white)
        // Use CIColorControls to increase contrast, then threshold
        processed = processed.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: 2.0,
            kCIInputBrightnessKey: -0.3
        ])
        
        // Apply color threshold to make it binary
        processed = processed.applyingFilter("CIColorThreshold", parameters: [
            "inputThreshold": 0.5
        ])
        
        return processed
    }
    
    // MARK: - Step 5: Find Pupil Centroid
    
    private static func findPupilCentroid(in image: CIImage) -> PupilPosition? {
        let context = CIContext()
        
        // Convert CIImage to CGImage for contour detection
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        
        // Convert to vImage buffer for processing
        guard let (width, height, data) = cgImageToGrayscaleData(cgImage) else {
            return nil
        }
        
        // Find connected components (contours)
        guard let (centroidX, centroidY) = findLargestDarkRegionCentroid(
            data: data,
            width: width,
            height: height
        ) else {
            return nil
        }
        
        return PupilPosition(x: CGFloat(centroidX), y: CGFloat(centroidY))
    }
    
    // MARK: - Helper: Convert CGImage to Grayscale Data
    
    private static func cgImageToGrayscaleData(_ cgImage: CGImage) -> (width: Int, height: Int, data: [UInt8])? {
        let width = cgImage.width
        let height = cgImage.height
        
        var data = [UInt8](repeating: 0, count: width * height)
        
        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return (width, height, data)
    }
    
    // MARK: - Helper: Find Centroid of Largest Dark Region
    
    private static func findLargestDarkRegionCentroid(
        data: [UInt8],
        width: Int,
        height: Int
    ) -> (x: Double, y: Double)? {
        
        // Calculate image moments to find centroid
        // m00 = sum of all pixels (area)
        // m10 = sum of (x * pixel_value)
        // m01 = sum of (y * pixel_value)
        // centroid_x = m10 / m00
        // centroid_y = m01 / m00
        
        var m00: Double = 0
        var m10: Double = 0
        var m01: Double = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let pixelValue = 255 - Int(data[index])  // Invert: we want dark regions
                
                if pixelValue > 128 {  // Only count dark pixels
                    let weight = Double(pixelValue)
                    m00 += weight
                    m10 += Double(x) * weight
                    m01 += Double(y) * weight
                }
            }
        }
        
        guard m00 > 0 else { return nil }
        
        let centroidX = m10 / m00
        let centroidY = m01 / m00
        
        return (centroidX, centroidY)
    }
}
