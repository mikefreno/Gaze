//
//  UsageTrackingServiceTests.swift
//  GazeTests
//
//  Unit tests for UsageTrackingService.
//

import XCTest
@testable import Gaze

@MainActor
final class UsageTrackingServiceTests: XCTestCase {
    
    var service: UsageTrackingService!
    
    override func setUp() async throws {
        service = UsageTrackingService(resetThresholdMinutes: 60)
    }
    
    override func tearDown() async throws {
        service = nil
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service)
    }
    
    func testInitializationWithCustomThreshold() {
        let customService = UsageTrackingService(resetThresholdMinutes: 120)
        XCTAssertNotNil(customService)
    }
    
    // MARK: - Threshold Tests
    
    func testUpdateResetThreshold() {
        service.updateResetThreshold(minutes: 90)
        
        // Should not crash
        XCTAssertNotNil(service)
    }
    
    func testUpdateThresholdMultipleTimes() {
        service.updateResetThreshold(minutes: 30)
        service.updateResetThreshold(minutes: 60)
        service.updateResetThreshold(minutes: 120)
        
        XCTAssertNotNil(service)
    }
    
    // MARK: - Idle Monitoring Integration Tests
    
    func testSetupIdleMonitoring() {
        let idleService = IdleMonitoringService(idleThresholdMinutes: 5)
        
        service.setupIdleMonitoring(idleService)
        
        // Should not crash
        XCTAssertNotNil(service)
    }
}
