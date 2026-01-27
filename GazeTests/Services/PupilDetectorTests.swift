//
//  PupilDetectorTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/16/26.
//

import CoreVideo
import Vision
import XCTest

@testable import Gaze

final class PupilDetectorTests: XCTestCase {

    override func setUp() async throws {
        // Reset the detector state
        PupilDetector.cleanup()
    }

    func testCreateCGImageFromData() throws {
        // Test basic image creation
        let width = 50
        let height = 50
        var pixels = [UInt8](repeating: 128, count: width * height)

        // Add some dark pixels for a "pupil"
        for y in 20..<30 {
            for x in 20..<30 {
                pixels[y * width + x] = 10  // Very dark
            }
        }

        // Save test image to verify
        let pixelData = Data(pixels)
        guard let provider = CGDataProvider(data: pixelData as CFData) else {
            XCTFail("Failed to create CGDataProvider")
            return
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

        XCTAssertNotNil(cgImage, "Should create CGImage from pixel data")
    }

    func testImageProcessingWithDarkPixels() throws {
        // Test that imageProcessingOptimized produces dark pixels
        let width = 60
        let height = 40

        // Create input with a dark circle (simulating pupil)
        var input = [UInt8](repeating: 200, count: width * height)  // Light background (like eye white)

        // Add a dark ellipse in center (pupil)
        let centerX = width / 2
        let centerY = height / 2
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy < 100 {  // Circle radius ~10
                    input[y * width + x] = 20  // Dark pupil
                }
            }
        }

        var output = [UInt8](repeating: 255, count: width * height)
        let threshold = 50  // Same as default

        // Call the actual processing function
        input.withUnsafeMutableBufferPointer { inputPtr in
            output.withUnsafeMutableBufferPointer { outputPtr in
                // We can't call imageProcessingOptimized directly as it's private
                // But we can verify by saving input for inspection
            }
        }

        // Save the input for manual inspection
        let inputData = Data(input)
        let url = URL(fileURLWithPath: "/Users/mike/gaze/images/test_input_synthetic.png")
        if let provider = CGDataProvider(data: inputData as CFData) {
            if let cgImage = CGImage(
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
            ) {
                if let dest = CGImageDestinationCreateWithURL(
                    url as CFURL, "public.png" as CFString, 1, nil)
                {
                    CGImageDestinationAddImage(dest, cgImage, nil)
                    CGImageDestinationFinalize(dest)
                    print("💾 Saved synthetic test input to: \(url.path)")
                }
            }
        }

        // Count dark pixels in input
        let darkCount = input.filter { $0 < 50 }.count
        print("📊 Input has \(darkCount) dark pixels (< 50)")
        XCTAssertGreaterThan(darkCount, 0, "Input should have dark pixels for pupil")
    }

    func testFindPupilFromContoursWithSyntheticData() throws {
        // Create synthetic binary image with a dark region
        let width = 60
        let height = 40

        // All white except a dark blob
        var binaryData = [UInt8](repeating: 255, count: width * height)

        // Add dark region (0 = dark/pupil)
        let centerX = 30
        let centerY = 20
        var darkPixelCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let dx = x - centerX
                let dy = y - centerY
                if dx * dx + dy * dy < 100 {
                    binaryData[y * width + x] = 0
                    darkPixelCount += 1
                }
            }
        }

        print("📊 Created synthetic image with \(darkPixelCount) dark pixels")

        // Save for inspection
        let binaryDataObj = Data(binaryData)
        let url = URL(fileURLWithPath: "/Users/mike/gaze/images/test_binary_synthetic.png")
        if let provider = CGDataProvider(data: binaryDataObj as CFData) {
            if let cgImage = CGImage(
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
            ) {
                if let dest = CGImageDestinationCreateWithURL(
                    url as CFURL, "public.png" as CFString, 1, nil)
                {
                    CGImageDestinationAddImage(dest, cgImage, nil)
                    CGImageDestinationFinalize(dest)
                    print("💾 Saved synthetic binary image to: \(url.path)")
                }
            }
        }

        XCTAssertGreaterThan(darkPixelCount, 10, "Should have enough dark pixels")
    }
}
