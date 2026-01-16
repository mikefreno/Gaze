//
//  PupilDetector.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//
//  Pixel-based pupil detection translated from Python GazeTracking library
//  Original: https://github.com/antoinelame/GazeTracking
//
//  Optimized with:
//  - Frame skipping (process every Nth frame)
//  - vImage/Accelerate for grayscale conversion and erosion
//  - Precomputed lookup tables for bilateral filter
//  - Efficient contour detection with union-find
//

import Accelerate
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Vision

struct PupilPosition: Equatable, Sendable {
    let x: CGFloat
    let y: CGFloat
}

struct EyeRegion: Sendable {
    let frame: CGRect
    let center: CGPoint
    let origin: CGPoint
}

/// 9-point gaze direction grid
enum GazeDirection: String, Sendable, CaseIterable {
    case upLeft = "↖"
    case up = "↑"
    case upRight = "↗"
    case left = "←"
    case center = "●"
    case right = "→"
    case downLeft = "↙"
    case down = "↓"
    case downRight = "↘"

    /// Thresholds for direction detection
    /// Horizontal: 0.0 = looking right (from camera POV), 1.0 = looking left
    /// Vertical: 0.0 = looking up, 1.0 = looking down
    private static let horizontalLeftThreshold = 0.55  // Above this = looking left
    private static let horizontalRightThreshold = 0.45  // Below this = looking right
    private static let verticalUpThreshold = 0.40  // Below this = looking up
    private static let verticalDownThreshold = 0.60  // Above this = looking down

    static func from(horizontal: Double, vertical: Double) -> GazeDirection {
        let isLeft = horizontal > horizontalLeftThreshold
        let isRight = horizontal < horizontalRightThreshold
        let isUp = vertical < verticalUpThreshold
        let isDown = vertical > verticalDownThreshold

        if isUp {
            if isLeft { return .upLeft }
            if isRight { return .upRight }
            return .up
        } else if isDown {
            if isLeft { return .downLeft }
            if isRight { return .downRight }
            return .down
        } else {
            if isLeft { return .left }
            if isRight { return .right }
            return .center
        }
    }

    /// Grid position (0-2 for x and y)
    var gridPosition: (x: Int, y: Int) {
        switch self {
        case .upLeft: return (0, 0)
        case .up: return (1, 0)
        case .upRight: return (2, 0)
        case .left: return (0, 1)
        case .center: return (1, 1)
        case .right: return (2, 1)
        case .downLeft: return (0, 2)
        case .down: return (1, 2)
        case .downRight: return (2, 2)
        }
    }
}

/// Calibration state for adaptive thresholding (matches Python Calibration class)
final class PupilCalibration: @unchecked Sendable {
    private let lock = NSLock()
    private let targetFrames = 20
    private var thresholdsLeft: [Int] = []
    private var thresholdsRight: [Int] = []

    nonisolated var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return thresholdsLeft.count >= targetFrames && thresholdsRight.count >= targetFrames
    }

    nonisolated func threshold(forSide side: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let thresholds = side == 0 ? thresholdsLeft : thresholdsRight
        // DEBUG: Use higher default threshold (was 50)
        guard !thresholds.isEmpty else { return 90 }
        return thresholds.reduce(0, +) / thresholds.count
    }

    nonisolated func evaluate(eyeData: UnsafePointer<UInt8>, width: Int, height: Int, side: Int) {
        let bestThreshold = findBestThreshold(eyeData: eyeData, width: width, height: height)
        lock.lock()
        defer { lock.unlock() }
        if side == 0 {
            thresholdsLeft.append(bestThreshold)
        } else {
            thresholdsRight.append(bestThreshold)
        }
    }

    private nonisolated func findBestThreshold(
        eyeData: UnsafePointer<UInt8>, width: Int, height: Int
    ) -> Int {
        let averageIrisSize = 0.48
        var bestThreshold = 50
        var bestDiff = Double.greatestFiniteMagnitude

        let bufferSize = width * height
        let tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { tempBuffer.deallocate() }

        for threshold in stride(from: 5, to: 100, by: 5) {
            PupilDetector.imageProcessingOptimized(
                input: eyeData,
                output: tempBuffer,
                width: width,
                height: height,
                threshold: threshold
            )
            let irisSize = Self.irisSize(data: tempBuffer, width: width, height: height)
            let diff = abs(irisSize - averageIrisSize)
            if diff < bestDiff {
                bestDiff = diff
                bestThreshold = threshold
            }
        }

        return bestThreshold
    }

    private nonisolated static func irisSize(data: UnsafePointer<UInt8>, width: Int, height: Int)
        -> Double
    {
        let margin = 5
        guard width > margin * 2, height > margin * 2 else { return 0 }

        var blackCount = 0
        let innerWidth = width - margin * 2
        let innerHeight = height - margin * 2

        for y in margin..<(height - margin) {
            let rowStart = y * width + margin
            for x in 0..<innerWidth {
                if data[rowStart + x] == 0 {
                    blackCount += 1
                }
            }
        }

        let totalCount = innerWidth * innerHeight
        return totalCount > 0 ? Double(blackCount) / Double(totalCount) : 0
    }

    nonisolated func reset() {
        lock.lock()
        defer { lock.unlock() }
        thresholdsLeft.removeAll()
        thresholdsRight.removeAll()
    }
}

/// Performance metrics for pupil detection
struct PupilDetectorMetrics: Sendable {
    var lastProcessingTimeMs: Double = 0
    var averageProcessingTimeMs: Double = 0
    var frameCount: Int = 0
    var processedFrameCount: Int = 0

    mutating func recordProcessingTime(_ ms: Double) {
        lastProcessingTimeMs = ms
        processedFrameCount += 1
        let alpha = 0.1
        averageProcessingTimeMs = averageProcessingTimeMs * (1 - alpha) + ms * alpha
    }
}

final class PupilDetector: @unchecked Sendable {

    // MARK: - Thread Safety

    private static let lock = NSLock()

    // MARK: - Configuration

    nonisolated(unsafe) static var enableDebugImageSaving: Bool = false  // Disabled - causes sandbox errors
    nonisolated(unsafe) static var enablePerformanceLogging = false
    nonisolated(unsafe) static var enableDiagnosticLogging = false  // Disabled - pupil detection now working
    nonisolated(unsafe) static var enableDebugLogging: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    nonisolated(unsafe) static var frameSkipCount = 10  // Process every Nth frame

    // MARK: - State (protected by lock)

    private nonisolated(unsafe) static var _debugImageCounter = 0
    private nonisolated(unsafe) static var _frameCounter = 0
    private nonisolated(unsafe) static var _lastPupilPositions:
        (left: PupilPosition?, right: PupilPosition?) = (
            nil, nil
        )
    private nonisolated(unsafe) static var _metrics = PupilDetectorMetrics()
    
    // Debug images for UI display
    nonisolated(unsafe) static var debugLeftEyeInput: CGImage?
    nonisolated(unsafe) static var debugRightEyeInput: CGImage?
    nonisolated(unsafe) static var debugLeftEyeProcessed: CGImage?
    nonisolated(unsafe) static var debugRightEyeProcessed: CGImage?
    nonisolated(unsafe) static var debugLeftPupilPosition: PupilPosition?
    nonisolated(unsafe) static var debugRightPupilPosition: PupilPosition?
    nonisolated(unsafe) static var debugLeftEyeSize: CGSize?
    nonisolated(unsafe) static var debugRightEyeSize: CGSize?
    
    // Eye region positions in image coordinates (for drawing on video)
    nonisolated(unsafe) static var debugLeftEyeRegion: EyeRegion?
    nonisolated(unsafe) static var debugRightEyeRegion: EyeRegion?
    nonisolated(unsafe) static var debugImageSize: CGSize?

    nonisolated(unsafe) static let calibration = PupilCalibration()

    // MARK: - Convenience Properties

    private nonisolated static var debugImageCounter: Int {
        get { _debugImageCounter }
        set { _debugImageCounter = newValue }
    }

    private nonisolated static var frameCounter: Int {
        get { _frameCounter }
        set { _frameCounter = newValue }
    }

    private nonisolated static var lastPupilPositions: (left: PupilPosition?, right: PupilPosition?)
    {
        get { _lastPupilPositions }
        set { _lastPupilPositions = newValue }
    }

    private nonisolated static var metrics: PupilDetectorMetrics {
        get { _metrics }
        set { _metrics = newValue }
    }

    // MARK: - Precomputed Tables

    private nonisolated(unsafe) static let spatialWeightsLUT: [[Float]] = {
        let d = 10
        let radius = d / 2
        let sigmaSpace: Float = 15.0
        var weights = [[Float]](repeating: [Float](repeating: 0, count: d), count: d)
        for dy in 0..<d {
            for dx in 0..<d {
                let dist = sqrt(
                    Float((dy - radius) * (dy - radius) + (dx - radius) * (dx - radius)))
                weights[dy][dx] = exp(-dist * dist / (2 * sigmaSpace * sigmaSpace))
            }
        }
        return weights
    }()

    private nonisolated(unsafe) static let colorWeightsLUT: [Float] = {
        let sigmaColor: Float = 15.0
        var lut = [Float](repeating: 0, count: 256)
        for diff in 0..<256 {
            let d = Float(diff)
            lut[diff] = exp(-d * d / (2 * sigmaColor * sigmaColor))
        }
        return lut
    }()

    // MARK: - Reusable Buffers

    private nonisolated(unsafe) static var grayscaleBuffer: UnsafeMutablePointer<UInt8>?
    private nonisolated(unsafe) static var grayscaleBufferSize = 0
    private nonisolated(unsafe) static var eyeBuffer: UnsafeMutablePointer<UInt8>?
    private nonisolated(unsafe) static var eyeBufferSize = 0
    private nonisolated(unsafe) static var tempBuffer: UnsafeMutablePointer<UInt8>?
    private nonisolated(unsafe) static var tempBufferSize = 0

    // MARK: - Public API

    /// Call once per video frame to enable proper frame skipping
    nonisolated static func advanceFrame() {
        frameCounter += 1
    }

    /// Detects pupil position with frame skipping for performance
    /// Returns cached result on skipped frames
    nonisolated static func detectPupil(
        in pixelBuffer: CVPixelBuffer,
        eyeLandmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize,
        side: Int = 0,
        threshold: Int? = nil
    ) -> (pupilPosition: PupilPosition, eyeRegion: EyeRegion)? {
        // Frame skipping - return cached result
        if frameCounter % frameSkipCount != 0 {
            let cachedPosition = side == 0 ? lastPupilPositions.left : lastPupilPositions.right
            if let position = cachedPosition {
                // Recreate eye region for consistency
                let eyePoints = landmarksToPixelCoordinates(
                    landmarks: eyeLandmarks,
                    faceBoundingBox: faceBoundingBox,
                    imageSize: imageSize
                )
                if let eyeRegion = createEyeRegion(from: eyePoints, imageSize: imageSize) {
                    return (position, eyeRegion)
                }
            }
            return nil
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            if enablePerformanceLogging {
                let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
                metrics.recordProcessingTime(elapsed)
                if metrics.processedFrameCount % 30 == 0 {
                    logDebug(
                        "👁 PupilDetector: \(String(format: "%.2f", elapsed))ms (avg: \(String(format: "%.2f", metrics.averageProcessingTimeMs))ms)"
                    )
                }
            }
        }

        // Step 1: Convert Vision landmarks to pixel coordinates
        let eyePoints = landmarksToPixelCoordinates(
            landmarks: eyeLandmarks,
            faceBoundingBox: faceBoundingBox,
            imageSize: imageSize
        )

        guard eyePoints.count >= 6 else {
            if enableDiagnosticLogging {
                logDebug("👁 PupilDetector: Failed - eyePoints.count=\(eyePoints.count) < 6")
            }
            return nil
        }

        // Step 2: Create eye region bounding box with margin
        guard let eyeRegion = createEyeRegion(from: eyePoints, imageSize: imageSize) else {
            if enableDiagnosticLogging {
                logDebug("👁 PupilDetector: Failed - createEyeRegion returned nil")
            }
            return nil
        }
        
        // Store eye region for debug overlay
        if side == 0 {
            debugLeftEyeRegion = eyeRegion
        } else {
            debugRightEyeRegion = eyeRegion
        }
        debugImageSize = imageSize

        let frameWidth = CVPixelBufferGetWidth(pixelBuffer)
        let frameHeight = CVPixelBufferGetHeight(pixelBuffer)
        let frameSize = frameWidth * frameHeight

        // Step 3: Ensure buffers are allocated
        ensureBufferCapacity(
            frameSize: frameSize, eyeSize: Int(eyeRegion.frame.width * eyeRegion.frame.height))

        guard let grayBuffer = grayscaleBuffer,
            let eyeBuf = eyeBuffer,
            let tmpBuf = tempBuffer
        else {
            if enableDiagnosticLogging {
                logDebug("👁 PupilDetector: Failed - buffers not allocated")
            }
            return nil
        }

        // Step 4: Extract grayscale data using vImage
        guard
            extractGrayscaleDataOptimized(
                from: pixelBuffer, to: grayBuffer, width: frameWidth, height: frameHeight)
        else {
            if enableDiagnosticLogging {
                logDebug("👁 PupilDetector: Failed - grayscale extraction failed")
            }
            return nil
        }

        // Step 5: Isolate eye with polygon mask
        let eyeWidth = Int(eyeRegion.frame.width)
        let eyeHeight = Int(eyeRegion.frame.height)

        // Early exit for tiny regions (less than 10x10 pixels)
        guard eyeWidth >= 10, eyeHeight >= 10 else {
            if enableDiagnosticLogging {
                logDebug(
                    "👁 PupilDetector: Failed - eye region too small (\(eyeWidth)x\(eyeHeight))")
            }
            return nil
        }

        guard
            isolateEyeWithMaskOptimized(
                frameData: grayBuffer,
                frameWidth: frameWidth,
                frameHeight: frameHeight,
                eyePoints: eyePoints,
                region: eyeRegion,
                output: eyeBuf
            )
        else {
            if enableDiagnosticLogging {
                logDebug("👁 PupilDetector: Failed - isolateEyeWithMask failed")
            }
            return nil
        }

        // Step 6: Get threshold (from calibration or parameter)
        let effectiveThreshold: Int
        if let manualThreshold = threshold {
            effectiveThreshold = manualThreshold
        } else if calibration.isComplete {
            effectiveThreshold = calibration.threshold(forSide: side)
        } else {
            calibration.evaluate(eyeData: eyeBuf, width: eyeWidth, height: eyeHeight, side: side)
            effectiveThreshold = calibration.threshold(forSide: side)
        }

        // Step 7: Process image (bilateral filter + erosion + threshold)
        if enableDiagnosticLogging {
            logDebug(
                "👁 PupilDetector: Using threshold=\(effectiveThreshold) for \(eyeWidth)x\(eyeHeight) eye region"
            )
        }

        // Debug: Save input eye image before processing
        if enableDebugImageSaving && debugImageCounter < 20 {
            NSLog(
                "📸 Saving eye_input_%d - %dx%d, side=%d, region=(%.0f,%.0f,%.0f,%.0f)",
                debugImageCounter, eyeWidth, eyeHeight, side,
                eyeRegion.frame.origin.x, eyeRegion.frame.origin.y,
                eyeRegion.frame.width, eyeRegion.frame.height)

            // Debug: Print pixel value statistics for input
            var minVal: UInt8 = 255
            var maxVal: UInt8 = 0
            var sum: Int = 0
            var darkCount = 0  // pixels <= 90
            for i in 0..<(eyeWidth * eyeHeight) {
                let v = eyeBuf[i]
                if v < minVal { minVal = v }
                if v > maxVal { maxVal = v }
                sum += Int(v)
                if v <= 90 { darkCount += 1 }
            }
            let avgVal = Double(sum) / Double(eyeWidth * eyeHeight)
            NSLog(
                "📊 Eye input stats: min=%d, max=%d, avg=%.1f, darkPixels(<=90)=%d", minVal, maxVal,
                avgVal, darkCount)

            saveDebugImage(
                data: eyeBuf, width: eyeWidth, height: eyeHeight,
                name: "eye_input_\(debugImageCounter)")
        }

        imageProcessingOptimized(
            input: eyeBuf,
            output: tmpBuf,
            width: eyeWidth,
            height: eyeHeight,
            threshold: effectiveThreshold
        )
        
        // Capture debug images for UI display
        let inputImage = createCGImage(from: eyeBuf, width: eyeWidth, height: eyeHeight)
        let processedImage = createCGImage(from: tmpBuf, width: eyeWidth, height: eyeHeight)
        let eyeSize = CGSize(width: eyeWidth, height: eyeHeight)
        if side == 0 {
            debugLeftEyeInput = inputImage
            debugLeftEyeProcessed = processedImage
            debugLeftEyeSize = eyeSize
        } else {
            debugRightEyeInput = inputImage
            debugRightEyeProcessed = processedImage
            debugRightEyeSize = eyeSize
        }

        // Debug: Save processed images if enabled
        if enableDebugImageSaving && debugImageCounter < 10 {
            // Debug: Print pixel value statistics for output
            var darkCount = 0  // pixels == 0 (black)
            var whiteCount = 0  // pixels == 255 (white)
            for i in 0..<(eyeWidth * eyeHeight) {
                if tmpBuf[i] == 0 { darkCount += 1 } else if tmpBuf[i] == 255 { whiteCount += 1 }
            }
            NSLog("📊 Processed output stats: darkPixels=%d, whitePixels=%d", darkCount, whiteCount)

            saveDebugImage(
                data: tmpBuf, width: eyeWidth, height: eyeHeight,
                name: "processed_eye_\(debugImageCounter)")
            debugImageCounter += 1
        }

        // Step 8: Find contours and compute centroid
        guard
            let (centroidX, centroidY) = findPupilFromContoursOptimized(
                data: tmpBuf,
                width: eyeWidth,
                height: eyeHeight
            )
        else {
            if enableDiagnosticLogging {
                logDebug(
                    "👁 PupilDetector: Failed - findPupilFromContours returned nil (not enough dark pixels) for side \(side)"
                )
            }
            return nil
        }

        if enableDiagnosticLogging {
            logDebug(
                "👁 PupilDetector: Success side=\(side) - centroid at (\(String(format: "%.1f", centroidX)), \(String(format: "%.1f", centroidY))) in \(eyeWidth)x\(eyeHeight) region"
            )
        }

        let pupilPosition = PupilPosition(x: CGFloat(centroidX), y: CGFloat(centroidY))

        // Cache result and debug position
        if side == 0 {
            lastPupilPositions.left = pupilPosition
            debugLeftPupilPosition = pupilPosition
        } else {
            lastPupilPositions.right = pupilPosition
            debugRightPupilPosition = pupilPosition
        }

        return (pupilPosition, eyeRegion)
    }

    // MARK: - Buffer Management

    // MARK: - Buffer Management

    private nonisolated static func ensureBufferCapacity(frameSize: Int, eyeSize: Int) {
        if grayscaleBufferSize < frameSize {
            grayscaleBuffer?.deallocate()
            grayscaleBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: frameSize)
            grayscaleBufferSize = frameSize
        }

        let requiredEyeSize = max(eyeSize, 10000)  // Minimum size for safety
        if eyeBufferSize < requiredEyeSize {
            eyeBuffer?.deallocate()
            tempBuffer?.deallocate()
            eyeBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: requiredEyeSize)
            tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: requiredEyeSize)
            eyeBufferSize = requiredEyeSize
        }
    }

    // MARK: - Optimized Grayscale Conversion (vImage)

    private nonisolated static func extractGrayscaleDataOptimized(
        from pixelBuffer: CVPixelBuffer,
        to output: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int
    ) -> Bool {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

            var srcBuffer = vImage_Buffer(
                data: baseAddress,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: bytesPerRow
            )

            var dstBuffer = vImage_Buffer(
                data: output,
                height: vImagePixelCount(height),
                width: vImagePixelCount(width),
                rowBytes: width
            )

            // BGRA to Planar8 grayscale using luminance coefficients
            // Y = 0.299*R + 0.587*G + 0.114*B
            let matrix: [Int16] = [
                28,  // B coefficient (0.114 * 256 ≈ 29, adjusted)
                150,  // G coefficient (0.587 * 256 ≈ 150)
                77,  // R coefficient (0.299 * 256 ≈ 77)
                0,  // A coefficient
            ]
            let divisor: Int32 = 256

            let error = vImageMatrixMultiply_ARGB8888ToPlanar8(
                &srcBuffer,
                &dstBuffer,
                matrix,
                divisor,
                nil,
                0,
                vImage_Flags(kvImageNoFlags)
            )

            return error == kvImageNoError

        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            guard let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
                return false
            }
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let yBuffer = yPlane.assumingMemoryBound(to: UInt8.self)

            // Direct copy of Y plane (already grayscale)
            for y in 0..<height {
                memcpy(
                    output.advanced(by: y * width), yBuffer.advanced(by: y * yBytesPerRow), width)
            }
            return true

        default:
            // Fallback to manual conversion
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return false }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

            for y in 0..<height {
                for x in 0..<width {
                    let offset = y * bytesPerRow + x * 4
                    let b = Float(buffer[offset])
                    let g = Float(buffer[offset + 1])
                    let r = Float(buffer[offset + 2])
                    output[y * width + x] = UInt8(0.299 * r + 0.587 * g + 0.114 * b)
                }
            }
            return true
        }
    }

    // MARK: - Optimized Eye Isolation

    private nonisolated static func isolateEyeWithMaskOptimized(
        frameData: UnsafePointer<UInt8>,
        frameWidth: Int,
        frameHeight: Int,
        eyePoints: [CGPoint],
        region: EyeRegion,
        output: UnsafeMutablePointer<UInt8>
    ) -> Bool {
        let minX = Int(region.frame.origin.x)
        let minY = Int(region.frame.origin.y)
        let eyeWidth = Int(region.frame.width)
        let eyeHeight = Int(region.frame.height)

        guard eyeWidth > 0, eyeHeight > 0 else { return false }

        // Initialize to WHITE (255) - masked pixels should be bright so they don't affect pupil detection
        memset(output, 255, eyeWidth * eyeHeight)

        // Convert eye points to local coordinates
        let localPoints = eyePoints.map { point in
            (x: Float(point.x) - Float(minX), y: Float(point.y) - Float(minY))
        }

        // Precompute edge data for faster point-in-polygon
        let edges = (0..<localPoints.count).map { i in
            let p1 = localPoints[i]
            let p2 = localPoints[(i + 1) % localPoints.count]
            return (x1: p1.x, y1: p1.y, x2: p2.x, y2: p2.y)
        }

        for y in 0..<eyeHeight {
            let py = Float(y)
            for x in 0..<eyeWidth {
                let px = Float(x)

                if pointInPolygonFast(px: px, py: py, edges: edges) {
                    let frameX = minX + x
                    let frameY = minY + y

                    if frameX >= 0, frameX < frameWidth, frameY >= 0, frameY < frameHeight {
                        output[y * eyeWidth + x] = frameData[frameY * frameWidth + frameX]
                    }
                }
            }
        }

        return true
    }

    @inline(__always)
    private nonisolated static func pointInPolygonFast(
        px: Float, py: Float, edges: [(x1: Float, y1: Float, x2: Float, y2: Float)]
    ) -> Bool {
        var inside = false
        for edge in edges {
            if ((edge.y1 > py) != (edge.y2 > py))
                && (px < (edge.x2 - edge.x1) * (py - edge.y1) / (edge.y2 - edge.y1) + edge.x1)
            {
                inside = !inside
            }
        }
        return inside
    }

    // MARK: - Optimized Image Processing

    nonisolated static func imageProcessingOptimized(
        input: UnsafePointer<UInt8>,
        output: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        threshold: Int
    ) {
        let size = width * height
        guard size > 0 else { return }

        // SIMPLIFIED: Skip blur to avoid contaminating dark pupil pixels with bright mask pixels
        // Apply binary threshold directly to input
        for i in 0..<size {
            output[i] = input[i] > UInt8(threshold) ? 255 : 0
        }
    }

    private nonisolated static func gaussianBlurOptimized(
        input: UnsafePointer<UInt8>,
        output: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int
    ) {
        // Use a more appropriate convolution for performance
        // Using vImageTentConvolve_Planar8 with optimized parameters

        var srcBuffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(mutating: input),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width
        )

        var dstBuffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(output),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width
        )

        // Kernel size that provides good blur with minimal computational overhead
        let kernelSize: UInt32 = 5

        vImageTentConvolve_Planar8(
            &srcBuffer,
            &dstBuffer,
            nil,
            0, 0,
            kernelSize,
            kernelSize,
            0,
            vImage_Flags(kvImageEdgeExtend)
        )
    }

    private nonisolated static func erodeOptimized(
        input: UnsafePointer<UInt8>,
        output: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        iterations: Int
    ) {
        guard iterations > 0 else {
            memcpy(output, input, width * height)
            return
        }

        // Copy input to output first so we can use output as working buffer
        memcpy(output, input, width * height)

        var srcBuffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(output),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width
        )

        // Allocate temp buffer for ping-pong
        let tempData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        defer { tempData.deallocate() }

        var dstBuffer = vImage_Buffer(
            data: UnsafeMutableRawPointer(tempData),
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: width
        )

        // 3x3 erosion kernel (all ones)
        let kernel: [UInt8] = [
            1, 1, 1,
            1, 1, 1,
            1, 1, 1,
        ]

        for i in 0..<iterations {
            if i % 2 == 0 {
                vImageErode_Planar8(
                    &srcBuffer, &dstBuffer, 0, 0, kernel, 3, 3, vImage_Flags(kvImageNoFlags))
            } else {
                vImageErode_Planar8(
                    &dstBuffer, &srcBuffer, 0, 0, kernel, 3, 3, vImage_Flags(kvImageNoFlags))
            }
        }

        // If odd iterations, result is in dstBuffer (tempData), copy to output
        if iterations % 2 == 1 {
            memcpy(output, tempData, width * height)
        }
        // If even iterations, result is already in srcBuffer (output)
    }

    // MARK: - Optimized Contour Detection

    /// Optimized centroid-of-dark-pixels approach - much faster than union-find
    /// Returns the centroid of the largest dark region
    private nonisolated static func findPupilFromContoursOptimized(
        data: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) -> (x: Double, y: Double)? {

        // Optimized approach: find centroid of all black pixels
        // This works well for pupil detection since the pupil is the main dark blob

        var sumX: Int = 0
        var sumY: Int = 0
        var count: Int = 0

        // After binary thresholding, pixels are 0 (black/pupil) or 255 (white/background)
        // Use threshold of 128 to catch any pixels that are closer to black
        let threshold = UInt8(128)

        // Process entire image to get accurate centroid
        for y in 0..<height {
            let rowOffset = y * width
            for x in 0..<width {
                if data[rowOffset + x] < threshold {
                    sumX += x
                    sumY += y
                    count += 1
                }
            }
        }

        if enableDiagnosticLogging && count < 5 {
            logDebug("👁 PupilDetector: Dark pixel count = \(count) (need >= 5)")
        }

        // Minimum 5 pixels for valid pupil (reduced from 10 for small eye regions)
        guard count >= 5 else { return nil }

        return (
            x: Double(sumX) / Double(count),
            y: Double(sumY) / Double(count)
        )
    }

    // MARK: - Helper Methods

    private nonisolated static func landmarksToPixelCoordinates(
        landmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> [CGPoint] {
        // Vision uses bottom-left origin (normalized 0-1), CVPixelBuffer uses top-left
        // We need to flip Y: flippedY = 1.0 - y
        return landmarks.normalizedPoints.map { point in
            let imageX =
                (faceBoundingBox.origin.x + point.x * faceBoundingBox.width) * imageSize.width
            // Flip Y coordinate for pixel buffer coordinate system
            let flippedY = 1.0 - (faceBoundingBox.origin.y + point.y * faceBoundingBox.height)
            let imageY = flippedY * imageSize.height
            return CGPoint(x: imageX, y: imageY)
        }
    }

    private nonisolated static func createEyeRegion(from points: [CGPoint], imageSize: CGSize)
        -> EyeRegion?
    {
        guard !points.isEmpty else { return nil }

        let margin: CGFloat = 5
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

        minX -= margin
        maxX += margin
        minY -= margin
        maxY += margin

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

        let center = CGPoint(x: frame.width / 2, y: frame.height / 2)
        let origin = CGPoint(x: clampedMinX, y: clampedMinY)

        return EyeRegion(frame: frame, center: center, origin: origin)
    }

    // MARK: - Debug Helpers

    private nonisolated static func saveDebugImage(
        data: UnsafePointer<UInt8>, width: Int, height: Int, name: String
    ) {
        guard let cgImage = createCGImage(from: data, width: width, height: height) else {
            NSLog("⚠️ PupilDetector: createCGImage failed for %@ (%dx%d)", name, width, height)
            return
        }

        let url = URL(fileURLWithPath: "/tmp/gaze_debug/\(name).png")
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else {
            NSLog("⚠️ PupilDetector: CGImageDestinationCreateWithURL failed for %@", url.path)
            return
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        let success = CGImageDestinationFinalize(destination)
        if success {
            NSLog("💾 Saved debug image: %@", url.path)
        } else {
            NSLog("⚠️ PupilDetector: CGImageDestinationFinalize failed for %@", url.path)
        }
    }

    private nonisolated static func createCGImage(
        from data: UnsafePointer<UInt8>, width: Int, height: Int
    )
        -> CGImage?
    {
        guard width > 0 && height > 0 else {
            print("⚠️ PupilDetector: Invalid dimensions \(width)x\(height)")
            return nil
        }

        // Create a Data object that copies the pixel data
        let pixelData = Data(bytes: data, count: width * height)

        // Create CGImage from the data using CGDataProvider
        guard let provider = CGDataProvider(data: pixelData as CFData) else {
            print("⚠️ PupilDetector: CGDataProvider creation failed")
            return nil
        }

        let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )

        if cgImage == nil {
            print("⚠️ PupilDetector: CGImage creation failed")
        }

        return cgImage
    }

    /// Clean up allocated buffers (call on app termination if needed)
    nonisolated static func cleanup() {
        grayscaleBuffer?.deallocate()
        grayscaleBuffer = nil
        grayscaleBufferSize = 0

        eyeBuffer?.deallocate()
        eyeBuffer = nil

        tempBuffer?.deallocate()
        tempBuffer = nil
        eyeBufferSize = 0
    }
}
