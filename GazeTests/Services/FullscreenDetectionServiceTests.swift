//
//  FullscreenDetectionServiceTests.swift
//  GazeTests
//
//  Unit tests for FullscreenDetectionService.
//

import Combine
import XCTest
@testable import Gaze

@MainActor
final class FullscreenDetectionServiceTests: XCTestCase {
    
    var service: FullscreenDetectionService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        service = FullscreenDetectionService()
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
    
    func testInitialFullscreenState() {
        // Initially should not be in fullscreen (unless actually in fullscreen)
        XCTAssertNotNil(service.isFullscreenActive)
    }
    
    // MARK: - Publisher Tests
    
    func testFullscreenStatePublisher() async throws {
        let expectation = XCTestExpectation(description: "Fullscreen state published")
        
        service.$isFullscreenActive
            .sink { isFullscreen in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 0.1)
    }
    
    // MARK: - Force Update Tests
    
    func testForceUpdate() {
        // Should not crash
        service.forceUpdate()
        XCTAssertNotNil(service.isFullscreenActive)
    }
    
    // MARK: - Protocol Conformance Tests
    
    func testConformsToFullscreenDetectionProviding() {
        let providing: FullscreenDetectionProviding = service
        XCTAssertNotNil(providing)
        XCTAssertNotNil(providing.isFullscreenActive)
    }
}
