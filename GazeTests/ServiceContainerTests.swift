//
//  ServiceContainerTests.swift
//  GazeTests
//
//  Tests for the dependency injection infrastructure.
//

import XCTest
@testable import Gaze

@MainActor
final class ServiceContainerTests: XCTestCase {
    
    func testProductionContainerCreation() {
        let container = ServiceContainer.shared
        
        XCTAssertFalse(container.isTestEnvironment)
        XCTAssertNotNil(container.settingsManager)
        XCTAssertNotNil(container.enforceModeService)
    }
    
    func testTestContainerCreation() {
        let settings = AppSettings.onlyLookAwayEnabled
        let container = ServiceContainer.forTesting(settings: settings)
        
        XCTAssertTrue(container.isTestEnvironment)
        XCTAssertEqual(container.settingsManager.settings.lookAwayTimer.enabled, true)
        XCTAssertEqual(container.settingsManager.settings.blinkTimer.enabled, false)
    }
    
    func testTimerEngineCreation() {
        let container = ServiceContainer.forTesting()
        let timerEngine = container.timerEngine
        
        XCTAssertNotNil(timerEngine)
        // Second access should return the same instance
        XCTAssertTrue(container.timerEngine === timerEngine)
    }
    
    func testCustomTimerEngineInjection() {
        let container = ServiceContainer.forTesting()
        let mockSettings = EnhancedMockSettingsManager(settings: .shortIntervals)
        let customEngine = TimerEngine(
            settingsManager: mockSettings,
            timeProvider: MockTimeProvider()
        )
        
        container.setTimerEngine(customEngine)
        XCTAssertTrue(container.timerEngine === customEngine)
    }
    
    func testContainerReset() {
        let container = ServiceContainer.forTesting()
        
        // Access timer engine to create it
        _ = container.timerEngine
        
        // Reset should clear the timer engine
        container.reset()
        
        // Accessing again should create a new instance
        let newEngine = container.timerEngine
        XCTAssertNotNil(newEngine)
    }
}
