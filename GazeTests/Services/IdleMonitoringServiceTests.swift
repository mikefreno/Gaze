//
//  IdleMonitoringServiceTests.swift
//  GazeTests
//
//  Unit tests for IdleMonitoringService.
//

import Combine
import XCTest
@testable import Gaze

@MainActor
final class IdleMonitoringServiceTests: XCTestCase {
    
    var service: IdleMonitoringService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        service = IdleMonitoringService(idleThresholdMinutes: 5)
        cancellables = []
    }
    
    override func tearDown() async throws {
        cancellables = nil
        service = nil
    }
    
    // MARK: - Initialization Tests
    
    func testServiceInitialization() {
        XCTAssertNotNil(service)
    }
    
    func testInitialIdleState() {
        // Initially should not be idle
        XCTAssertFalse(service.isIdle)
    }
    
    func testInitializationWithCustomThreshold() {
        let customService = IdleMonitoringService(idleThresholdMinutes: 10)
        XCTAssertNotNil(customService)
    }
    
    // MARK: - Threshold Tests
    
    func testUpdateThreshold() {
        service.updateThreshold(minutes: 15)
        
        // Should not crash
        XCTAssertNotNil(service)
    }
    
    func testUpdateThresholdMultipleTimes() {
        service.updateThreshold(minutes: 5)
        service.updateThreshold(minutes: 10)
        service.updateThreshold(minutes: 3)
        
        XCTAssertNotNil(service)
    }
    
    // MARK: - Publisher Tests
    
    func testIdleStatePublisher() async throws {
        let expectation = XCTestExpectation(description: "Idle state published")
        
        service.$isIdle
            .sink { isIdle in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 0.1)
    }
    
    // MARK: - Force Update Tests
    
    func testForceUpdate() {
        service.forceUpdate()
        XCTAssertNotNil(service.isIdle)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testConformsToIdleMonitoringProviding() {
        let providing: IdleMonitoringProviding = service
        XCTAssertNotNil(providing)
        XCTAssertNotNil(providing.isIdle)
    }
}
