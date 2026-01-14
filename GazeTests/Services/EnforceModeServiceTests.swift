//
//  EnforceModeServiceTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/13/26.
//

import XCTest
@testable import Gaze

@MainActor
final class EnforceModeServiceTests: XCTestCase {
    var enforceModeService: EnforceModeService!
    var settingsManager: SettingsManager!
    
    override func setUp() async throws {
        settingsManager = SettingsManager.shared
        enforceModeService = EnforceModeService.shared
    }
    
    override func tearDown() async throws {
        enforceModeService.disableEnforceMode()
        settingsManager.settings.enforcementMode = false
    }
    
    func testEnforceModeServiceInitialization() {
        XCTAssertNotNil(enforceModeService)
        XCTAssertFalse(enforceModeService.isEnforceModeActive)
        XCTAssertFalse(enforceModeService.userCompliedWithBreak)
    }
    
    func testDisableEnforceModeResetsState() {
        enforceModeService.disableEnforceMode()
        
        XCTAssertFalse(enforceModeService.isEnforceModeActive)
        XCTAssertFalse(enforceModeService.userCompliedWithBreak)
    }
    
    func testShouldEnforceBreakOnlyForLookAwayTimer() {
        settingsManager.settings.enforcementMode = true
        
        let shouldEnforceLookAway = enforceModeService.shouldEnforceBreak(for: .builtIn(.lookAway))
        XCTAssertFalse(shouldEnforceLookAway)
        
        let shouldEnforceBlink = enforceModeService.shouldEnforceBreak(for: .builtIn(.blink))
        XCTAssertFalse(shouldEnforceBlink)
        
        let shouldEnforcePosture = enforceModeService.shouldEnforceBreak(for: .builtIn(.posture))
        XCTAssertFalse(shouldEnforcePosture)
    }
    
    func testCheckUserComplianceWhenNotActive() {
        enforceModeService.checkUserCompliance()
        
        XCTAssertFalse(enforceModeService.userCompliedWithBreak)
    }
}
