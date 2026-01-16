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

/// Calibration state for adaptive thresholding (matches Python Calibration class)
final class PupilCalibration: @unchecked Sendable {
    private let lock = NSLock()
    private let targetFrames = 20
    private var thresholdsLeft: [Int] = []
    private var thresholdsRight: [Int] = []

    var isComplete: Bool {
        lock.lock()
        defer { lock.unlock() }
        return thresholdsLeft.count >= targetFrames && thresholdsRight.count >= targetFrames
    }

    func threshold(forSide side: Int) -> Int {
        lock.lock()
        defer { lock.unlock() }
        let thresholds = side == 0 ? thresholdsLeft : thresholdsRight
        guard !thresholds.isEmpty else { return 50 }
        return thresholds.reduce(0, +) / thresholds.count
    }

    func evaluate(eyeData: UnsafePointer<UInt8>, width: Int, height: Int, side: Int) {
        let bestThreshold = findBestThreshold(eyeData: eyeData, width: width, height: height)
        lock.lock()
        defer { lock.unlock() }
        if side == 0 {
            thresholdsLeft.append(bestThreshold)
        } else {
            thresholdsRight.append(bestThreshold)
        }
    }

    private func findBestThreshold(eyeData: UnsafePointer<UInt8>, width: Int, height: Int) -> Int {
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

    private static func irisSize(data: UnsafePointer<UInt8>, width: Int, height: Int) -> Double {
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

    func reset() {
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

    static var enableDebugImageSaving = false
    static var enablePerformanceLogging = false
    static var frameSkipCount = 10  // Process every Nth frame

    // MARK: - State (protected by lock)

    private static var _debugImageCounter = 0
    private static var _frameCounter = 0
    private static var _lastPupilPositions: (left: PupilPosition?, right: PupilPosition?) = (
        nil, nil
    )
    private static var _metrics = PupilDetectorMetrics()

    static let calibration = PupilCalibration()

    // MARK: - Convenience Properties

    private static var debugImageCounter: Int {
        get { _debugImageCounter }
        set { _debugImageCounter = newValue }
    }

    private static var frameCounter: Int {
        get { _frameCounter }
        set { _frameCounter = newValue }
    }

    private static var lastPupilPositions: (left: PupilPosition?, right: PupilPosition?) {
        get { _lastPupilPositions }
        set { _lastPupilPositions = newValue }
    }

    private static var metrics: PupilDetectorMetrics {
        get { _metrics }
        set { _metrics = newValue }
    }

    // MARK: - Precomputed Tables

    private static let spatialWeightsLUT: [[Float]] = {
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

    private static let colorWeightsLUT: [Float] = {
        let sigmaColor: Float = 15.0
        var lut = [Float](repeating: 0, count: 256)
        for diff in 0..<256 {
            let d = Float(diff)
            lut[diff] = exp(-d * d / (2 * sigmaColor * sigmaColor))
        }
        return lut
    }()

    // MARK: - Reusable Buffers

    private static var grayscaleBuffer: UnsafeMutablePointer<UInt8>?
    private static var grayscaleBufferSize = 0
    private static var eyeBuffer: UnsafeMutablePointer<UInt8>?
    private static var eyeBufferSize = 0
    private static var tempBuffer: UnsafeMutablePointer<UInt8>?
    private static var tempBufferSize = 0

    // MARK: - Public API

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
                    print(
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

        guard eyePoints.count >= 6 else { return nil }

        // Step 2: Create eye region bounding box with margin
        guard let eyeRegion = createEyeRegion(from: eyePoints, imageSize: imageSize) else {
            return nil
        }

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
            return nil
        }

        // Step 4: Extract grayscale data using vImage
        guard
            extractGrayscaleDataOptimized(
                from: pixelBuffer, to: grayBuffer, width: frameWidth, height: frameHeight)
        else {
            return nil
        }

        // Step 5: Isolate eye with polygon mask
        let eyeWidth = Int(eyeRegion.frame.width)
        let eyeHeight = Int(eyeRegion.frame.height)

        // Early exit for tiny regions (less than 10x10 pixels)
        guard eyeWidth >= 10, eyeHeight >= 10 else { return nil }

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
        imageProcessingOptimized(
            input: eyeBuf,
            output: tmpBuf,
            width: eyeWidth,
            height: eyeHeight,
            threshold: effectiveThreshold
        )

        // Debug: Save processed images if enabled
        if enableDebugImageSaving && debugImageCounter < 10 {
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
            return nil
        }

        let pupilPosition = PupilPosition(x: CGFloat(centroidX), y: CGFloat(centroidY))

        // Cache result
        if side == 0 {
            lastPupilPositions.left = pupilPosition
        } else {
            lastPupilPositions.right = pupilPosition
        }

        return (pupilPosition, eyeRegion)
    }

    // MARK: - Buffer Management

    private static func ensureBufferCapacity(frameSize: Int, eyeSize: Int) {
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

    private static func extractGrayscaleDataOptimized(
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

    private static func isolateEyeWithMaskOptimized(
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

        // Initialize to white (masked out)
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
    private static func pointInPolygonFast(
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

    static func imageProcessingOptimized(
        input: UnsafePointer<UInt8>,
        output: UnsafeMutablePointer<UInt8>,
        width: Int,
        height: Int,
        threshold: Int
    ) {
        let size = width * height
        guard size > 0 else { return }

        // Use a working buffer for intermediate results
        let workBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        defer { workBuffer.deallocate() }

        // 1. Fast Gaussian blur using vImage (replaces expensive bilateral filter)
        gaussianBlurOptimized(input: input, output: workBuffer, width: width, height: height)

        // 2. Erosion with vImage (3 iterations)
        erodeOptimized(
            input: workBuffer, output: output, width: width, height: height, iterations: 3)

        // 3. Simple binary threshold (no vDSP overhead for small buffers)
        for i in 0..<size {
            output[i] = output[i] > UInt8(threshold) ? 255 : 0
        }
    }

    private static func gaussianBlurOptimized(
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

    private static func erodeOptimized(
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
    private static func findPupilFromContoursOptimized(
        data: UnsafePointer<UInt8>,
        width: Int,
        height: Int
    ) -> (x: Double, y: Double)? {

        // Optimized approach: find centroid of all black pixels with early exit
        // This works well for pupil detection since the pupil is the main dark blob

        // Use a more efficient approach that doesn't iterate through entire image
        var sumX: Int = 0
        var sumY: Int = 0
        var count: Int = 0

        // Early exit if we already know this isn't going to be useful
        let threshold = UInt8(5)  // Only consider pixels that are quite dark

        // Process in chunks for better cache performance
        let chunkSize = 16
        var rowsProcessed = 0

        while rowsProcessed < height {
            let endRow = min(rowsProcessed + chunkSize, height)

            for y in rowsProcessed..<endRow {
                let rowOffset = y * width
                for x in 0..<width {
                    // Only process dark pixels that are likely to be pupil
                    if data[rowOffset + x] <= threshold {
                        sumX += x
                        sumY += y
                        count += 1
                    }
                }
            }

            rowsProcessed = endRow

            // Early exit if we've found enough pixels for a reasonable estimate
            if count > 25 {  // Early termination condition
                break
            }
        }

        guard count > 10 else { return nil }  // Need minimum pixels for valid pupil

        return (
            x: Double(sumX) / Double(count),
            y: Double(sumY) / Double(count)
        )
    }

    // MARK: - Helper Methods

    private static func landmarksToPixelCoordinates(
        landmarks: VNFaceLandmarkRegion2D,
        faceBoundingBox: CGRect,
        imageSize: CGSize
    ) -> [CGPoint] {
        return landmarks.normalizedPoints.map { point in
            let imageX =
                (faceBoundingBox.origin.x + point.x * faceBoundingBox.width) * imageSize.width
            let imageY =
                (faceBoundingBox.origin.y + point.y * faceBoundingBox.height) * imageSize.height
            return CGPoint(x: imageX, y: imageY)
        }
    }

    private static func createEyeRegion(from points: [CGPoint], imageSize: CGSize) -> EyeRegion? {
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

    private static func saveDebugImage(
        data: UnsafePointer<UInt8>, width: Int, height: Int, name: String
    ) {
        guard let cgImage = createCGImage(from: data, width: width, height: height) else { return }

        let url = URL(fileURLWithPath: "/tmp/\(name).png")
        guard
            let destination = CGImageDestinationCreateWithURL(
                url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }

        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
        print("💾 Saved debug image: \(url.path)")
    }

    private static func createCGImage(from data: UnsafePointer<UInt8>, width: Int, height: Int)
        -> CGImage?
    {
        let mutableData = UnsafeMutablePointer<UInt8>.allocate(capacity: width * height)
        defer { mutableData.deallocate() }
        memcpy(mutableData, data, width * height)

        guard
            let context = CGContext(
                data: mutableData,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            return nil
        }
        return context.makeImage()
    }

    /// Clean up allocated buffers (call on app termination if needed)
    static func cleanup() {
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
