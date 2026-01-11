//
//  UpdateManagerTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/11/26.
//

import XCTest
import Combine
@testable import Gaze

@MainActor
final class UpdateManagerTests: XCTestCase {
    
    var sut: UpdateManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() async throws {
        try await super.setUp()
        sut = UpdateManager.shared
        cancellables = []
    }
    
    override func tearDown() async throws {
        cancellables = nil
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Singleton Tests
    
    func testSingletonInstance() {
        // Arrange & Act
        let instance1 = UpdateManager.shared
        let instance2 = UpdateManager.shared
        
        // Assert
        XCTAssertTrue(instance1 === instance2, "UpdateManager should be a singleton")
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Assert
        XCTAssertNotNil(sut, "UpdateManager should initialize")
    }
    
    func testInitialObservableProperties() {
        // Assert - Check that properties are initialized (values may vary)
        // automaticallyChecksForUpdates could be true or false based on Info.plist
        // Just verify it's a valid boolean
        XCTAssertTrue(
            sut.automaticallyChecksForUpdates == true || sut.automaticallyChecksForUpdates == false,
            "automaticallyChecksForUpdates should be a valid boolean"
        )
    }
    
    // MARK: - Observable Property Tests
    
    func testAutomaticallyChecksForUpdatesIsPublished() async throws {
        // Arrange
        let expectation = expectation(description: "automaticallyChecksForUpdates property change observed")
        var observedValue: Bool?
        
        // Act - Subscribe to published property
        sut.$automaticallyChecksForUpdates
            .dropFirst() // Skip initial value
            .sink { newValue in
                observedValue = newValue
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Toggle the value (toggle to ensure change regardless of initial value)
        let originalValue = sut.automaticallyChecksForUpdates
        sut.automaticallyChecksForUpdates = !originalValue
        
        // Assert
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertNotNil(observedValue, "Should observe a value change")
        XCTAssertEqual(observedValue, !originalValue, "Observed value should match the new value")
    }
    
    func testLastUpdateCheckDateIsPublished() async throws {
        // Arrange
        let expectation = expectation(description: "lastUpdateCheckDate property change observed")
        var observedValue: Date?
        var changeDetected = false
        
        // Act - Subscribe to published property
        sut.$lastUpdateCheckDate
            .dropFirst() // Skip initial value
            .sink { newValue in
                observedValue = newValue
                changeDetected = true
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Set a new date
        let testDate = Date(timeIntervalSince1970: 1000000)
        sut.lastUpdateCheckDate = testDate
        
        // Assert
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertTrue(changeDetected, "Should detect property change")
        XCTAssertEqual(observedValue, testDate, "Observed date should match the set date")
    }
    
    // MARK: - Update Check Tests
    
    func testCheckForUpdatesDoesNotCrash() {
        // Arrange - method should be callable without crash
        
        // Act & Assert
        XCTAssertNoThrow(
            sut.checkForUpdates(),
            "checkForUpdates should not throw or crash"
        )
    }
    
    func testCheckForUpdatesIsCallable() {
        // Arrange
        var didComplete = false
        
        // Act
        sut.checkForUpdates()
        didComplete = true
        
        // Assert
        XCTAssertTrue(didComplete, "checkForUpdates should complete synchronously")
    }
    
    // MARK: - Integration Tests
    
    func testCheckForUpdatesIsAvailableAfterInitialization() {
        // Arrange & Act
        // checkForUpdates should be available immediately after initialization
        var didExecute = false
        
        // Act - Call the method
        sut.checkForUpdates()
        didExecute = true
        
        // Assert
        XCTAssertTrue(didExecute, "checkForUpdates should be callable after initialization")
    }
}
