//
//  LoggingManagerTests.swift
//  GazeTests
//
//  Unit tests for LoggingManager.
//

import os.log
import XCTest
@testable import Gaze

final class LoggingManagerTests: XCTestCase {
    
    var loggingManager: LoggingManager!
    
    override func setUp() {
        loggingManager = LoggingManager.shared
    }
    
    override func tearDown() {
        loggingManager = nil
    }
    
    // MARK: - Initialization Tests
    
    func testLoggingManagerInitialization() {
        XCTAssertNotNil(loggingManager)
    }
    
    func testLoggersExist() {
        XCTAssertNotNil(loggingManager.appLogger)
        XCTAssertNotNil(loggingManager.timerLogger)
        XCTAssertNotNil(loggingManager.systemLogger)
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureLogging() {
        // Should not crash
        loggingManager.configureLogging()
        XCTAssertNotNil(loggingManager)
    }
    
    // MARK: - Logger Usage Tests
    
    func testAppLoggerLogging() {
        // Should not crash
        loggingManager.appLogger.info("Test app log")
        XCTAssertNotNil(loggingManager.appLogger)
    }
    
    func testTimerLoggerLogging() {
        loggingManager.timerLogger.info("Test timer log")
        XCTAssertNotNil(loggingManager.timerLogger)
    }
    
    func testSystemLoggerLogging() {
        loggingManager.systemLogger.info("Test system log")
        XCTAssertNotNil(loggingManager.systemLogger)
    }
}
