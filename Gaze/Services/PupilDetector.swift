//
//  PupilDetector.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//
//  Pixel-based pupil detection translated from Python GazeTracking library
//  Original: https://github.com/antoinelame/GazeTracking
//
//  This implementation closely follows the Python pipeline:
//  1. Isolate eye region with polygon mask (cv2.fillPoly equivalent)
//  2. Bilateral filter (cv2.bilateralFilter(eye_frame, 10, 15, 15))
//  3. Erosion with 3x3 kernel, 3 iterations (cv2.erode)
//  4. Binary threshold (cv2.threshold)
//  5. Find contours, sort by area, use second-largest (cv2.findContours)
//  6. Calculate centroid via moments (cv2.moments)
//

import CoreImage
import Vision
import Accelerate
import ImageIO
import UniformTypeIdentifiers

struct PupilPosition {
    let x: CGFloat
    let y: CGFloat
}

struct EyeRegion {
    let frame: CGRect
    let center: CGPoint
    let origin: CGPoint
}

/// Calibration state for adaptive thresholding (matches Python Calibration class)
class PupilCalibration {
    private let targetFrames = 20
    private var thresholdsLeft: [Int] = []
    private var thresholdsRight: [Int] = []
    
    var isComplete: Bool {
        thresholdsLeft.count >= targetFrames && thresholdsRight.count >= targetFrames
    }
    
    func threshold(forSide side: Int) -> Int {
        let thresholds = side == 0 ? thresholdsLeft : thresholdsRight
        guard !thresholds.isEmpty else { return 50 }
        return thresholds.reduce(0, +) / thresholds.count
    }
    
    func evaluate(eyeData: [UInt8], width: Int, height: Int, side: Int) {
        let bestThreshold = findBestThreshold(eyeData: eyeData, width: width, height: height)
        if side == 0 {
            thresholdsLeft.append(bestThreshold)
        } else {
            thresholdsRight.append(bestThreshold)
        }
    }
    
    /// Finds optimal threshold by targeting ~48% iris coverage (matches Python)
    private func findBestThreshold(eyeData: [UInt8], width: Int, height: Int) -> Int {
        let averageIrisSize = 0.48
        var trials: [Int: Double] = [:]
        
        for threshold in stride(from: 5, to: 100, by: 5) {
            let processed = PupilDetector.imageProcessing(
                eyeData: eyeData,
                width: width,
                height: height,
                threshold: threshold
            )
            let irisSize = Self.irisSize(data: processed, width: width, height: height)
            trials[threshold] = irisSize
        }
        
        let best = trials.min { abs($0.value - averageIrisSize) < abs($1.value - averageIrisSize) }
        return best?.key ?? 50
    }
    
    /// Returns percentage of dark pixels (iris area)
    private static func irisSize(data: [UInt8], width: Int, height: Int) -> Double {
        let margin = 5
        guard width > margin * 2, height > margin * 2 else {
            return 0
        }
        
        var blackCount = 0
        var totalCount = 0
        
        for y in margin..<(height - margin) {
            for x in margin..<(width - margin) {
                let index = y * width + x
                if data[index] == 0 {
                    blackCount += 1
                }
                totalCount += 1
            }
        }
        
        return totalCount > 0 ? Double(blackCount) / Double(totalCount) : 0
    }
    
    func reset() {
        thresholdsLeft.removeAll()
        thresholdsRight.removeAll()
    }
}

class PupilDetector {
    
    static var enableDebugImageSaving = false
    private static var debugImageCounter = 0
    
    /// Shared calibration instance
    static let calibration = PupilCalibration()
    
    /// Detects pupil position within an isolated eye region
    /// Closely follows Python GazeTracking pipeline
    /// - Parameters:
    ///   - pixelBuffer: The camera frame pixel buffer
    ///   - eyeLandmarks: Vision eye landmarks (6 points around iris)
    ///   - faceBoundingBox: Face bounding box from Vision
    ///   - imageSize: Size of the camera frame
    ///   - side: 0 for left eye, 1 for right eye
    ///   - threshold: Optional manual threshold (uses calibration if nil)
    /// - Returns: Pupil position relative to eye region, or nil if detection fails
    static func detectPupil(
        in pixelBuffer: CVPixelBuffer,
        eyeLandmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize,
        side: Int = 0,
        threshold: Int? = nil
    ) -> (pupilPosition: PupilPosition, eyeRegion: EyeRegion)? {
        
        // Step 1: Convert Vision landmarks to pixel coordinates
        let eyePoints = landmarksToPixelCoordinates(
            landmarks: eyeLandmarks,
            faceBoundingBox: faceBoundingBox,
            imageSize: imageSize
        )
        
        guard eyePoints.count >= 6 else { return nil }
        
        // Step 2: Create eye region bounding box with margin
        guard let eyeRegion = createEyeRegion(from: eyePoints, imageSize: imageSize) else {
            return nil
        }
        
        // Step 3: Extract grayscale eye data from pixel buffer
        guard let fullFrameData = extractGrayscaleData(from: pixelBuffer) else {
            return nil
        }
        
        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        // Step 4: Isolate eye with polygon mask (matches Python _isolate method)
        guard let (eyeData, eyeWidth, eyeHeight) = isolateEyeWithMask(
            frameData: fullFrameData,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            eyePoints: eyePoints,
            region: eyeRegion
        ) else {
            return nil
        }
        
        // Step 5: Get threshold (from calibration or parameter)
        let effectiveThreshold: Int
        if let manualThreshold = threshold {
            effectiveThreshold = manualThreshold
        } else if calibration.isComplete {
            effectiveThreshold = calibration.threshold(forSide: side)
        } else {
            // Calibrate
            calibration.evaluate(eyeData: eyeData, width: eyeWidth, height: eyeHeight, side: side)
            effectiveThreshold = calibration.threshold(forSide: side)
        }
        
        // Step 6: Process image (bilateral filter + erosion + threshold)
        let processedData = imageProcessing(
            eyeData: eyeData,
            width: eyeWidth,
            height: eyeHeight,
            threshold: effectiveThreshold
        )
        
        // Debug: Save processed images if enabled
        if enableDebugImageSaving {
            saveDebugImage(data: processedData, width: eyeWidth, height: eyeHeight, name: "processed_eye_\(debugImageCounter)")
            debugImageCounter += 1
        }
        
        // Step 7: Find contours and compute centroid of second-largest
        guard let (centroidX, centroidY) = findPupilFromContours(
            data: processedData,
            width: eyeWidth,
            height: eyeHeight
        ) else {
            return nil
        }
        
        let pupilPosition = PupilPosition(x: CGFloat(centroidX), y: CGFloat(centroidY))
        return (pupilPosition, eyeRegion)
    }
    
    // MARK: - Debug Helper
    
    private static func saveDebugImage(data: [UInt8], width: Int, height: Int, name: String) {
        guard let cgImage = createCGImage(from: data, width: width, height: height) else {
            return
        }
        
        let url = URL(fileURLWithPath: "/tmp/\(name).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        print("💾 Saved debug image: \(url.path)")
    }
    
    private static func createCGImage(from data: [UInt8], width: Int, height: Int) -> CGImage? {
        var mutableData = data
        guard let context = CGContext(
            data: &mutableData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        return context.makeImage()
    }
    
    // MARK: - Step 1: Convert Landmarks to Pixel Coordinates
    
    private static func landmarksToPixelCoordinates(
        landmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> [CGPoint] {
        return landmarks.normalizedPoints.map { point in
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
        
        let origin = CGPoint(x: clampedMinX, y: clampedMinY)
        
        return EyeRegion(frame: frame, center: center, origin: origin)
    }
    
    // MARK: - Step 3: Extract Grayscale Data from Pixel Buffer
    
    private static func extractGrayscaleData(from pixelBuffer: CVPixelBuffer) -> [UInt8]? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }
        
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        var grayscaleData = [UInt8](repeating: 0, count: width * height)
        
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * 4
                    let b = Double(buffer[offset])
                    let g = Double(buffer[offset + 1])
                    let r = Double(buffer[offset + 2])
                    let gray = UInt8(0.299 * r + 0.587 * g + 0.114 * b)
                    grayscaleData[y * width + x] = gray
                }
            }
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            guard let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                return nil
            }
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let yBuffer = yPlane.assumingMemoryBound(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    grayscaleData[y * width + x] = yBuffer[y * yBytesPerRow + x]
                }
            }
        default:
            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * 4
                    if offset + 2 < bytesPerRow * height {
                        let b = Double(buffer[offset])
                        let g = Double(buffer[offset + 1])
                        let r = Double(buffer[offset + 2])
                        let gray = UInt8(0.299 * r + 0.587 * g + 0.114 * b)
                        grayscaleData[y * width + x] = gray
                    }
                }
            }
        }
        
        return grayscaleData
    }
    
    // MARK: - Step 4: Isolate Eye with Polygon Mask (matches Python _isolate)
    
    private static func isolateEyeWithMask(
        frameData: [UInt8],
        frameWidth: Int,
        frameHeight: Int,
        eyePoints: [CGPoint],
        region: EyeRegion
    ) -> (data: [UInt8], width: Int, height: Int)? {
        
        let minX = Int(region.frame.origin.x)
        let minY = Int(region.frame.origin.y)
        let eyeWidth = Int(region.frame.width)
        let eyeHeight = Int(region.frame.height)
        
        guard eyeWidth > 0, eyeHeight > 0 else { return nil }
        
        // Create output buffer initialized to white (255) - outside mask
        var eyeData = [UInt8](repeating: 255, count: eyeWidth * eyeHeight)
        
        // Convert eye points to local coordinates
        let localPoints = eyePoints.map { point in
            CGPoint(x: point.x - CGFloat(minX), y: point.y - CGFloat(minY))
        }
        
        // For each pixel in eye region, check if inside polygon
        for y in 0..<eyeHeight {
            for x in 0..<eyeWidth {
                let localPoint = CGPoint(x: CGFloat(x), y: CGFloat(y))
                
                if pointInPolygon(point: localPoint, polygon: localPoints) {
                    let frameX = minX + x
                    let frameY = minY + y
                    
                    if frameX >= 0, frameX < frameWidth, frameY >= 0, frameY < frameHeight {
                        let frameIndex = frameY * frameWidth + frameX
                        let eyeIndex = y * eyeWidth + x
                        eyeData[eyeIndex] = frameData[frameIndex]
                    }
                }
            }
        }
        
        return (eyeData, eyeWidth, eyeHeight)
    }
    
    /// Point-in-polygon test using ray casting algorithm
    private static func pointInPolygon(point: CGPoint, polygon: [CGPoint]) -> Bool {
        guard polygon.count >= 3 else { return false }
        
        var inside = false
        var j = polygon.count - 1
        
        for i in 0..<polygon.count {
            let pi = polygon[i]
            let pj = polygon[j]
            
            if ((pi.y > point.y) != (pj.y > point.y)) &&
                (point.x < (pj.x - pi.x) * (point.y - pi.y) / (pj.y - pi.y) + pi.x) {
                inside = !inside
            }
            j = i
        }
        
        return inside
    }
    
    // MARK: - Step 5: Image Processing (matches Python image_processing)
    
    /// Performs operations on the eye frame to isolate the iris
    /// Matches Python: bilateralFilter -> erode -> threshold
    static func imageProcessing(
        eyeData: [UInt8],
        width: Int,
        height: Int,
        threshold: Int
    ) -> [UInt8] {
        var processed = eyeData
        
        // 1. Bilateral filter approximation
        // Python: cv2.bilateralFilter(eye_frame, 10, 15, 15)
        processed = bilateralFilter(data: processed, width: width, height: height, d: 10, sigmaColor: 15, sigmaSpace: 15)
        
        // 2. Erosion with 3x3 kernel, 3 iterations
        // Python: cv2.erode(new_frame, kernel, iterations=3)
        for _ in 0..<3 {
            processed = erode3x3(data: processed, width: width, height: height)
        }
        
        // 3. Binary threshold
        // Python: cv2.threshold(new_frame, threshold, 255, cv2.THRESH_BINARY)[1]
        processed = binaryThreshold(data: processed, width: width, height: height, threshold: threshold)
        
        return processed
    }
    
    /// Bilateral filter approximation - preserves edges while smoothing
    private static func bilateralFilter(
        data: [UInt8],
        width: Int,
        height: Int,
        d: Int,
        sigmaColor: Double,
        sigmaSpace: Double
    ) -> [UInt8] {
        var output = data
        let radius = d / 2
        
        // Precompute spatial Gaussian weights
        var spatialWeights = [[Double]](repeating: [Double](repeating: 0, count: d), count: d)
        for dy in 0..<d {
            for dx in 0..<d {
                let dist = sqrt(Double((dy - radius) * (dy - radius) + (dx - radius) * (dx - radius)))
                spatialWeights[dy][dx] = exp(-dist * dist / (2 * sigmaSpace * sigmaSpace))
            }
        }
        
        for y in radius..<(height - radius) {
            for x in radius..<(width - radius) {
                let centerIndex = y * width + x
                let centerValue = Double(data[centerIndex])
                
                var sum = 0.0
                var weightSum = 0.0
                
                for dy in 0..<d {
                    for dx in 0..<d {
                        let ny = y + dy - radius
                        let nx = x + dx - radius
                        let neighborIndex = ny * width + nx
                        let neighborValue = Double(data[neighborIndex])
                        
                        let colorDiff = abs(neighborValue - centerValue)
                        let colorWeight = exp(-colorDiff * colorDiff / (2 * sigmaColor * sigmaColor))
                        
                        let weight = spatialWeights[dy][dx] * colorWeight
                        sum += neighborValue * weight
                        weightSum += weight
                    }
                }
                
                output[centerIndex] = UInt8(max(0, min(255, sum / weightSum)))
            }
        }
        
        return output
    }
    
    /// Erosion with 3x3 kernel (minimum filter)
    private static func erode3x3(data: [UInt8], width: Int, height: Int) -> [UInt8] {
        var output = data
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                var minVal: UInt8 = 255
                
                for dy in -1...1 {
                    for dx in -1...1 {
                        let index = (y + dy) * width + (x + dx)
                        minVal = min(minVal, data[index])
                    }
                }
                
                output[y * width + x] = minVal
            }
        }
        
        return output
    }
    
    /// Binary threshold
    private static func binaryThreshold(data: [UInt8], width: Int, height: Int, threshold: Int) -> [UInt8] {
        return data.map { pixel in
            Int(pixel) > threshold ? UInt8(255) : UInt8(0)
        }
    }
    
    // MARK: - Step 6: Find Contours and Centroid (matches Python detect_iris)
    
    /// Finds contours, sorts by area, and returns centroid of second-largest
    /// Matches Python: cv2.findContours + cv2.moments
    private static func findPupilFromContours(
        data: [UInt8],
        width: Int,
        height: Int
    ) -> (x: Double, y: Double)? {
        
        let contours = findContours(data: data, width: width, height: height)
        
        guard contours.count >= 2 else {
            if let largest = contours.max(by: { $0.count < $1.count }) {
                return computeCentroid(contour: largest)
            }
            return nil
        }
        
        // Sort by area (pixel count) descending
        let sorted = contours.sorted { $0.count > $1.count }
        
        // Use second-largest contour (matches Python: contours[-2] after ascending sort)
        let targetContour = sorted[1]
        
        return computeCentroid(contour: targetContour)
    }
    
    /// Finds connected components of black pixels (value == 0)
    private static func findContours(data: [UInt8], width: Int, height: Int) -> [[(x: Int, y: Int)]] {
        var visited = [Bool](repeating: false, count: width * height)
        var contours: [[(x: Int, y: Int)]] = []
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                
                if data[index] == 0 && !visited[index] {
                    var contour: [(x: Int, y: Int)] = []
                    var stack = [(x, y)]
                    
                    while !stack.isEmpty {
                        let (cx, cy) = stack.removeLast()
                        let cIndex = cy * width + cx
                        
                        if cx < 0 || cx >= width || cy < 0 || cy >= height {
                            continue
                        }
                        if visited[cIndex] || data[cIndex] != 0 {
                            continue
                        }
                        
                        visited[cIndex] = true
                        contour.append((cx, cy))
                        
                        // 8-connectivity
                        stack.append((cx + 1, cy))
                        stack.append((cx - 1, cy))
                        stack.append((cx, cy + 1))
                        stack.append((cx, cy - 1))
                        stack.append((cx + 1, cy + 1))
                        stack.append((cx - 1, cy - 1))
                        stack.append((cx + 1, cy - 1))
                        stack.append((cx - 1, cy + 1))
                    }
                    
                    if !contour.isEmpty {
                        contours.append(contour)
                    }
                }
            }
        }
        
        return contours
    }
    
    /// Computes centroid using image moments (matches cv2.moments)
    private static func computeCentroid(contour: [(x: Int, y: Int)]) -> (x: Double, y: Double)? {
        guard !contour.isEmpty else { return nil }
        
        let m00 = Double(contour.count)
        let m10 = contour.reduce(0.0) { $0 + Double($1.x) }
        let m01 = contour.reduce(0.0) { $0 + Double($1.y) }
        
        guard m00 > 0 else { return nil }
        
        return (m10 / m00, m01 / m00)
    }
}
