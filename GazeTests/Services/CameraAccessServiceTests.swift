//
//  CameraAccessServiceTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/13/26.
//

import XCTest
@testable import Gaze

@MainActor
final class CameraAccessServiceTests: XCTestCase {
    var cameraService: CameraAccessService!
    
    override func setUp() async throws {
        cameraService = CameraAccessService.shared
    }
    
    func testCameraServiceInitialization() {
        XCTAssertNotNil(cameraService)
    }
    
    func testCheckCameraAuthorizationStatus() {
        cameraService.checkCameraAuthorizationStatus()
        
        XCTAssertFalse(cameraService.isCameraAuthorized || cameraService.cameraError != nil)
    }
    
    func testIsFaceDetectionAvailable() {
        let isAvailable = cameraService.isFaceDetectionAvailable()
        
        XCTAssertEqual(isAvailable, cameraService.isCameraAuthorized)
    }
}
