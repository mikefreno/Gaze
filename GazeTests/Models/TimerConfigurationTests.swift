//
//  TimerConfigurationTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class TimerConfigurationTests: XCTestCase {
    
    func testInitialization() {
        let config = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.intervalSeconds, 1200)
    }
    
    func testInitializationDisabled() {
        let config = TimerConfiguration(enabled: false, intervalSeconds: 600)
        
        XCTAssertFalse(config.enabled)
        XCTAssertEqual(config.intervalSeconds, 600)
    }
    
    func testIntervalMinutesGetter() {
        let config = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        XCTAssertEqual(config.intervalMinutes, 20)
    }
    
    func testIntervalMinutesSetter() {
        var config = TimerConfiguration(enabled: true, intervalSeconds: 0)
        config.intervalMinutes = 15
        
        XCTAssertEqual(config.intervalMinutes, 15)
        XCTAssertEqual(config.intervalSeconds, 900)
    }
    
    func testIntervalMinutesConversion() {
        var config = TimerConfiguration(enabled: true, intervalSeconds: 0)
        
        config.intervalMinutes = 1
        XCTAssertEqual(config.intervalSeconds, 60)
        
        config.intervalMinutes = 60
        XCTAssertEqual(config.intervalSeconds, 3600)
        
        config.intervalMinutes = 0
        XCTAssertEqual(config.intervalSeconds, 0)
    }
    
    func testEquality() {
        let config1 = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        let config2 = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        let config3 = TimerConfiguration(enabled: false, intervalSeconds: 1200)
        let config4 = TimerConfiguration(enabled: true, intervalSeconds: 600)
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
        XCTAssertNotEqual(config1, config4)
    }
    
    func testCodableEncoding() throws {
        let config = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testCodableDecoding() throws {
        let config = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TimerConfiguration.self, from: data)
        
        XCTAssertEqual(decoded, config)
    }
    
    func testCodableRoundTrip() throws {
        let configs = [
            TimerConfiguration(enabled: true, intervalSeconds: 300),
            TimerConfiguration(enabled: false, intervalSeconds: 1200),
            TimerConfiguration(enabled: true, intervalSeconds: 1800),
            TimerConfiguration(enabled: false, intervalSeconds: 0)
        ]
        
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for config in configs {
            let data = try encoder.encode(config)
            let decoded = try decoder.decode(TimerConfiguration.self, from: data)
            XCTAssertEqual(decoded, config)
        }
    }
    
    func testMutability() {
        var config = TimerConfiguration(enabled: true, intervalSeconds: 1200)
        
        config.enabled = false
        XCTAssertFalse(config.enabled)
        
        config.intervalSeconds = 600
        XCTAssertEqual(config.intervalSeconds, 600)
        XCTAssertEqual(config.intervalMinutes, 10)
    }
    
    func testZeroInterval() {
        let config = TimerConfiguration(enabled: true, intervalSeconds: 0)
        XCTAssertEqual(config.intervalSeconds, 0)
        XCTAssertEqual(config.intervalMinutes, 0)
    }
    
    func testLargeInterval() {
        let config = TimerConfiguration(enabled: true, intervalSeconds: 86400)
        XCTAssertEqual(config.intervalSeconds, 86400)
        XCTAssertEqual(config.intervalMinutes, 1440)
    }
}
