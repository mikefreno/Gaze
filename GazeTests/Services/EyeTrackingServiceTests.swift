//
//  EyeTrackingServiceTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/13/26.
//

import XCTest
@testable import Gaze

@MainActor
final class EyeTrackingServiceTests: XCTestCase {
    var eyeTrackingService: EyeTrackingService!
    
    override func setUp() async throws {
        eyeTrackingService = EyeTrackingService.shared
    }
    
    override func tearDown() async throws {
        eyeTrackingService.stopEyeTracking()
    }
    
    func testEyeTrackingServiceInitialization() {
        XCTAssertNotNil(eyeTrackingService)
        XCTAssertFalse(eyeTrackingService.isEyeTrackingActive)
        XCTAssertFalse(eyeTrackingService.isEyesClosed)
        XCTAssertTrue(eyeTrackingService.userLookingAtScreen)
        XCTAssertFalse(eyeTrackingService.faceDetected)
    }
    
    func testStopEyeTrackingResetsState() {
        eyeTrackingService.stopEyeTracking()
        
        XCTAssertFalse(eyeTrackingService.isEyeTrackingActive)
        XCTAssertFalse(eyeTrackingService.isEyesClosed)
        XCTAssertTrue(eyeTrackingService.userLookingAtScreen)
        XCTAssertFalse(eyeTrackingService.faceDetected)
    }
}
