//
//  EnforcePolicyEvaluatorTests.swift
//  GazeTests
//
//  Unit tests for EnforcePolicyEvaluator (now nested in EnforceModeService).
//

import XCTest
@testable import Gaze

@MainActor
final class EnforcePolicyEvaluatorTests: XCTestCase {
    
    var evaluator: EnforcePolicyEvaluator!
    var mockSettings: EnhancedMockSettingsManager!
    
    override func setUp() async throws {
        mockSettings = EnhancedMockSettingsManager(settings: .defaults)
        evaluator = EnforcePolicyEvaluator(settingsProvider: mockSettings)
    }
    
    override func tearDown() async throws {
        evaluator = nil
        mockSettings = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(evaluator)
    }
    
    func testInitializationWithSettingsProvider() {
        let newSettings = EnhancedMockSettingsManager(settings: AppSettings.defaults)
        let newEvaluator = EnforcePolicyEvaluator(settingsProvider: newSettings)
        XCTAssertNotNil(newEvaluator)
    }
    
    // MARK: - Enforcement Enabled Tests
    
    func testIsEnforcementEnabledWhenLookAwayDisabled() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: false)
        
        let isEnabled = evaluator.isEnforcementEnabled
        
        XCTAssertFalse(isEnabled)
    }
    
    func testIsEnforcementEnabledWhenLookAwayEnabled() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let isEnabled = evaluator.isEnforcementEnabled
        
        XCTAssertTrue(isEnabled)
    }
    
    // MARK: - Should Enforce Tests
    
    func testShouldEnforceWhenLookAwayEnabled() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldEnforce = evaluator.shouldEnforce(timerIdentifier: .builtIn(.lookAway))
        
        XCTAssertTrue(shouldEnforce)
    }
    
    func testShouldEnforceWhenLookAwayDisabled() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: false)
        
        let shouldEnforce = evaluator.shouldEnforce(timerIdentifier: .builtIn(.lookAway))
        
        XCTAssertFalse(shouldEnforce)
    }
    
    func testShouldEnforceUserTimerNever() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldEnforce = evaluator.shouldEnforce(timerIdentifier: .user)
        
        XCTAssertFalse(shouldEnforce)
    }
    
    func testShouldEnforceBuiltInPostureTimerNever() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldEnforce = evaluator.shouldEnforce(timerIdentifier: .builtIn(.posture))
        
        XCTAssertFalse(shouldEnforce)
    }
    
    func testShouldEnforceBuiltInBlinkTimerNever() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldEnforce = evaluator.shouldEnforce(timerIdentifier: .builtIn(.blink))
        
        XCTAssertFalse(shouldEnforce)
    }
    
    // MARK: - Pre-activate Camera Tests
    
    func testShouldPreActivateCameraWhenTimerDisabled() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: false)
        
        let shouldPreActivate = evaluator.shouldPreActivateCamera(
            timerIdentifier: .builtIn(.lookAway),
            secondsRemaining: 3
        )
        
        XCTAssertFalse(shouldPreActivate)
    }
    
    func testShouldPreActivateCameraWhenSecondsRemainingTooHigh() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldPreActivate = evaluator.shouldPreActivateCamera(
            timerIdentifier: .builtIn(.lookAway),
            secondsRemaining: 5
        )
        
        XCTAssertFalse(shouldPreActivate)
    }
    
    func testShouldPreActivateCameraWhenAllConditionsMet() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldPreActivate = evaluator.shouldPreActivateCamera(
            timerIdentifier: .builtIn(.lookAway),
            secondsRemaining: 2
        )
        
        XCTAssertTrue(shouldPreActivate)
    }
    
    func testShouldPreActivateCameraForUserTimerNever() {
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        let shouldPreActivate = evaluator.shouldPreActivateCamera(
            timerIdentifier: .user,
            secondsRemaining: 1
        )
        
        XCTAssertFalse(shouldPreActivate)
    }
    
    // MARK: - Compliance Evaluation Tests
    
    func testEvaluateComplianceWhenLookingAtScreenAndFaceDetected() {
        let result = evaluator.evaluateCompliance(
            isLookingAtScreen: true,
            faceDetected: true
        )
        
        XCTAssertEqual(result, .notCompliant)
    }
    
    func testEvaluateComplianceWhenNotLookingAtScreenAndFaceDetected() {
        let result = evaluator.evaluateCompliance(
            isLookingAtScreen: false,
            faceDetected: true
        )
        
        XCTAssertEqual(result, .compliant)
    }
    
    func testEvaluateComplianceWhenFaceNotDetected() {
        let result = evaluator.evaluateCompliance(
            isLookingAtScreen: true,
            faceDetected: false
        )
        
        XCTAssertEqual(result, .faceNotDetected)
    }
    
    func testEvaluateComplianceWhenFaceNotDetectedAndNotLookingAtScreen() {
        let result = evaluator.evaluateCompliance(
            isLookingAtScreen: false,
            faceDetected: false
        )
        
        XCTAssertEqual(result, .faceNotDetected)
    }
    
    func testEvaluateComplianceWhenFaceNotDetectedAndNotLookingAtScreen() {
        // Test edge case - should still return face not detected
        let result = evaluator.evaluateCompliance(
            isLookingAtScreen: false,
            faceDetected: false
        )
        
        XCTAssertEqual(result, .faceNotDetected)
    }
    
    // MARK: - Integration Tests
    
    func testFullEnforcementFlow() {
        // Setup: Look away timer enabled
        mockSettings.updateTimerEnabled(for: .lookAway, enabled: true)
        
        // Test 1: Check enforcement
        let shouldEnforce = evaluator.shouldEnforce(timerIdentifier: .builtIn(.lookAway))
        XCTAssertTrue(shouldEnforce)
        
        // Test 2: Check pre-activation at 3 seconds
        let shouldPreActivate = evaluator.shouldPreActivateCamera(
            timerIdentifier: .builtIn(.lookAway),
            secondsRemaining: 3
        )
        XCTAssertTrue(shouldPreActivate)
        
        // Test 3: Check compliance when looking at screen
        let compliance = evaluator.evaluateCompliance(
            isLookingAtScreen: true,
            faceDetected: true
        )
        XCTAssertEqual(compliance, .notCompliant)
    }
}
