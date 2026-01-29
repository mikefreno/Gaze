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
        
        XCTAssertNotNil(container.settingsManager)
        XCTAssertNotNil(container.enforceModeService)
    }
    
    func testTestContainerCreation() {
        let settings = AppSettings.onlyLookAwayEnabled
        let container = TestServiceContainer(settings: settings)
        
        XCTAssertEqual(container.settingsManager.settings.lookAwayEnabled, true)
        XCTAssertEqual(container.settingsManager.settings.blinkEnabled, false)
    }
    
    func testTimerEngineCreation() {
        let container = TestServiceContainer()
        let timerEngine = container.timerEngine
        
        XCTAssertNotNil(timerEngine)
        // Second access should return the same instance
        XCTAssertTrue(container.timerEngine === timerEngine)
        XCTAssertTrue(container.timeProvider is MockTimeProvider)
    }
    
    func testCustomTimerEngineInjection() {
        let container = TestServiceContainer()
        let mockSettings = EnhancedMockSettingsManager(settings: .shortIntervals)
        let customEngine = TimerEngine(
            settingsManager: mockSettings,
            enforceModeService: nil,
            timeProvider: MockTimeProvider()
        )
        
        container.setTimerEngine(customEngine)
        XCTAssertTrue(container.timerEngine === customEngine)
    }
    
    func testContainerReset() {
        let container = TestServiceContainer()
        
        // Access timer engine to create it
        let existingEngine = container.timerEngine
        
        // Reset should clear the timer engine
        container.reset()
        
        // Accessing again should create a new instance
        let newEngine = container.timerEngine
        XCTAssertNotNil(newEngine)
        XCTAssertFalse(existingEngine === newEngine)
    }
}
