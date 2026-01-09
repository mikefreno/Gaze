//
//  AppSettingsTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class AppSettingsTests: XCTestCase {
    
    func testDefaultSettings() {
        let settings = AppSettings.defaults
        
        XCTAssertTrue(settings.lookAwayTimer.enabled)
        XCTAssertEqual(settings.lookAwayTimer.intervalSeconds, 20 * 60)
        XCTAssertEqual(settings.lookAwayCountdownSeconds, 20)
        
        XCTAssertTrue(settings.blinkTimer.enabled)
        XCTAssertEqual(settings.blinkTimer.intervalSeconds, 5 * 60)
        
        XCTAssertTrue(settings.postureTimer.enabled)
        XCTAssertEqual(settings.postureTimer.intervalSeconds, 30 * 60)
        
        XCTAssertFalse(settings.hasCompletedOnboarding)
        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.playSounds)
    }
    
    func testEquality() {
        let settings1 = AppSettings.defaults
        let settings2 = AppSettings.defaults
        
        XCTAssertEqual(settings1, settings2)
    }
    
    func testInequalityWhenLookAwayTimerDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.lookAwayTimer.enabled = false
        XCTAssertNotEqual(settings1, settings2)
        
        settings2.lookAwayTimer.enabled = true
        settings2.lookAwayTimer.intervalSeconds = 10 * 60
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testInequalityWhenCountdownDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.lookAwayCountdownSeconds = 30
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testInequalityWhenBlinkTimerDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.blinkTimer.enabled = false
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testInequalityWhenPostureTimerDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.postureTimer.intervalSeconds = 60 * 60
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testInequalityWhenOnboardingDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.hasCompletedOnboarding = true
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testInequalityWhenLaunchAtLoginDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.launchAtLogin = true
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testInequalityWhenPlaySoundsDiffers() {
        var settings1 = AppSettings.defaults
        var settings2 = AppSettings.defaults
        
        settings2.playSounds = false
        XCTAssertNotEqual(settings1, settings2)
    }
    
    func testCodableEncoding() throws {
        let settings = AppSettings.defaults
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data.count, 0)
    }
    
    func testCodableDecoding() throws {
        let settings = AppSettings.defaults
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        XCTAssertEqual(decoded, settings)
    }
    
    func testCodableRoundTripWithModifiedSettings() throws {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.enabled = false
        settings.lookAwayCountdownSeconds = 30
        settings.blinkTimer.intervalSeconds = 10 * 60
        settings.postureTimer.enabled = false
        settings.hasCompletedOnboarding = true
        settings.launchAtLogin = true
        settings.playSounds = false
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AppSettings.self, from: data)
        
        XCTAssertEqual(decoded, settings)
        XCTAssertFalse(decoded.lookAwayTimer.enabled)
        XCTAssertEqual(decoded.lookAwayCountdownSeconds, 30)
        XCTAssertEqual(decoded.blinkTimer.intervalSeconds, 10 * 60)
        XCTAssertFalse(decoded.postureTimer.enabled)
        XCTAssertTrue(decoded.hasCompletedOnboarding)
        XCTAssertTrue(decoded.launchAtLogin)
        XCTAssertFalse(decoded.playSounds)
    }
    
    func testMutability() {
        var settings = AppSettings.defaults
        
        settings.lookAwayTimer.enabled = false
        XCTAssertFalse(settings.lookAwayTimer.enabled)
        
        settings.lookAwayCountdownSeconds = 30
        XCTAssertEqual(settings.lookAwayCountdownSeconds, 30)
        
        settings.hasCompletedOnboarding = true
        XCTAssertTrue(settings.hasCompletedOnboarding)
        
        settings.launchAtLogin = true
        XCTAssertTrue(settings.launchAtLogin)
        
        settings.playSounds = false
        XCTAssertFalse(settings.playSounds)
    }
    
    func testBoundaryValues() {
        var settings = AppSettings.defaults
        
        settings.lookAwayTimer.intervalSeconds = 0
        XCTAssertEqual(settings.lookAwayTimer.intervalSeconds, 0)
        
        settings.lookAwayCountdownSeconds = 0
        XCTAssertEqual(settings.lookAwayCountdownSeconds, 0)
        
        settings.lookAwayTimer.intervalSeconds = Int.max
        XCTAssertEqual(settings.lookAwayTimer.intervalSeconds, Int.max)
    }
}
