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
    
    // MARK: - Should Enforce Tests
    
    func testShouldEnforceBreakWhenDisabled() {
        service.disableEnforceMode()
        
        let shouldEnforce = service.shouldEnforceBreak(for: .builtIn(.lookAway))
        XCTAssertFalse(shouldEnforce)
    }
    
    func testShouldEnforceLookAwayTimer() {
        let shouldEnforce = service.shouldEnforce(timerIdentifier: .builtIn(.lookAway))
        // Result depends on settings, but method should not crash
        XCTAssertNotNil(shouldEnforce)
    }
    
    func testShouldEnforceUserTimerNever() {
        let shouldEnforce = service.shouldEnforce(timerIdentifier: .user(id: "test"))
        XCTAssertFalse(shouldEnforce)
    }
    
    func testShouldEnforceBuiltInPostureTimerNever() {
        let shouldEnforce = service.shouldEnforce(timerIdentifier: .builtIn(.posture))
        XCTAssertFalse(shouldEnforce)
    }
    
    func testShouldEnforceBuiltInBlinkTimerNever() {
        let shouldEnforce = service.shouldEnforce(timerIdentifier: .builtIn(.blink))
        XCTAssertFalse(shouldEnforce)
    }
    
    // MARK: - Pre-activate Camera Tests
    
    func testShouldPreActivateCameraWhenSecondsRemainingTooHigh() {
        let shouldPreActivate = service.shouldPreActivateCamera(
            timerIdentifier: .builtIn(.lookAway),
            secondsRemaining: 5
        )
        XCTAssertFalse(shouldPreActivate)
    }
    
    func testShouldPreActivateCameraForUserTimerNever() {
        let shouldPreActivate = service.shouldPreActivateCamera(
            timerIdentifier: .user(id: "test"),
            secondsRemaining: 1
        )
        XCTAssertFalse(shouldPreActivate)
    }
    
    // MARK: - Compliance Evaluation Tests
    
    func testEvaluateComplianceWhenLookingAtScreenAndFaceDetected() {
        let result = service.evaluateCompliance(
            isLookingAtScreen: true,
            faceDetected: true
        )
        XCTAssertEqual(result, .notCompliant)
    }
    
    func testEvaluateComplianceWhenNotLookingAtScreenAndFaceDetected() {
        let result = service.evaluateCompliance(
            isLookingAtScreen: false,
            faceDetected: true
        )
        XCTAssertEqual(result, .compliant)
    }
    
    func testEvaluateComplianceWhenFaceNotDetected() {
        let result = service.evaluateCompliance(
            isLookingAtScreen: true,
            faceDetected: false
        )
        XCTAssertEqual(result, .faceNotDetected)
    }
    
    func testEvaluateComplianceWhenFaceNotDetectedAndNotLookingAtScreen() {
        let result = service.evaluateCompliance(
            isLookingAtScreen: false,
            faceDetected: false
        )
        XCTAssertEqual(result, .faceNotDetected)
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
        await service.enableEnforceMode()
        await service.startTestMode()
        
        // Test mode requires enforce mode to be enabled and camera permissions
        // Just verify it doesn't crash
        XCTAssertNotNil(service)
    }
    
    func testStopTestMode() {
        service.stopTestMode()
        
        XCTAssertFalse(service.isTestMode)
    }
    
    func testTestModeCycle() async {
        await service.enableEnforceMode()
        await service.startTestMode()
        
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
