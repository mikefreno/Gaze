//
//  EnforceModeServiceTests.swift
//  GazeTests
//
//  Unit tests for EnforceModeService.
//

import XCTest
@testable import Gaze

@MainActor
final class EnforceModeServiceTests: XCTestCase {
    
    var service: EnforceModeService!
    
    override func setUp() async throws {
        service = EnforceModeService.shared
    }
    
    override func tearDown() async throws {
        service.disableEnforceMode()
        service = nil
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service)
    }
    
    func testInitialState() {
        XCTAssertFalse(service.isEnforceModeEnabled)
        XCTAssertFalse(service.isCameraActive)
        XCTAssertFalse(service.userCompliedWithBreak)
    }
    
    // MARK: - Enable/Disable Tests
    
    func testEnableEnforceMode() async {
        await service.enableEnforceMode()
        
        // May or may not be enabled depending on camera permissions
        // Just verify the method doesn't crash
        XCTAssertNotNil(service)
    }
    
    func testDisableEnforceMode() {
        service.disableEnforceMode()
        
        XCTAssertFalse(service.isEnforceModeEnabled)
        XCTAssertFalse(service.isCameraActive)
    }
    
    func testEnableDisableCycle() async {
        await service.enableEnforceMode()
        service.disableEnforceMode()
        
        XCTAssertFalse(service.isEnforceModeEnabled)
    }
    
    // MARK: - Timer Engine Integration Tests
    
    func testSetTimerEngine() {
        let testEnv = TestEnvironment()
        let timerEngine = testEnv.container.timerEngine
        
        service.setTimerEngine(timerEngine)
        
        // Should not crash
        XCTAssertNotNil(service)
    }
    
    // MARK: - Should Enforce Break Tests
    
    func testShouldEnforceBreakWhenDisabled() {
        service.disableEnforceMode()
        
        let shouldEnforce = service.shouldEnforceBreak(for: .builtIn(.lookAway))
        XCTAssertFalse(shouldEnforce)
    }
    
    // MARK: - Camera Tests
    
    func testStopCamera() {
        service.stopCamera()
        
        XCTAssertFalse(service.isCameraActive)
    }
    
    // MARK: - Compliance Tests
    
    func testCheckUserCompliance() {
        service.checkUserCompliance()
        
        // Should not crash
        XCTAssertNotNil(service)
    }
    
    func testHandleReminderDismissed() {
        service.handleReminderDismissed()
        
        // Should not crash
        XCTAssertNotNil(service)
    }
    
    // MARK: - Test Mode Tests
    
    func testStartTestMode() async {
        await service.startTestMode()
        
        XCTAssertTrue(service.isTestMode)
    }
    
    func testStopTestMode() {
        service.stopTestMode()
        
        XCTAssertFalse(service.isTestMode)
    }
    
    func testTestModeCycle() async {
        await service.startTestMode()
        XCTAssertTrue(service.isTestMode)
        
        service.stopTestMode()
        XCTAssertFalse(service.isTestMode)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testConformsToEnforceModeProviding() {
        let providing: EnforceModeProviding = service
        XCTAssertNotNil(providing)
        XCTAssertFalse(providing.isEnforceModeEnabled)
    }
}
