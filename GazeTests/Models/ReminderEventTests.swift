//
//  ReminderEventTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class ReminderEventTests: XCTestCase {
    
    func testLookAwayTriggeredCreation() {
        let event = ReminderEvent.lookAwayTriggered(countdownSeconds: 20)
        
        if case .lookAwayTriggered(let countdown) = event {
            XCTAssertEqual(countdown, 20)
        } else {
            XCTFail("Expected lookAwayTriggered event")
        }
    }
    
    func testBlinkTriggeredCreation() {
        let event = ReminderEvent.blinkTriggered
        
        if case .blinkTriggered = event {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected blinkTriggered event")
        }
    }
    
    func testPostureTriggeredCreation() {
        let event = ReminderEvent.postureTriggered
        
        if case .postureTriggered = event {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected postureTriggered event")
        }
    }
    
    func testTypePropertyForLookAway() {
        let event = ReminderEvent.lookAwayTriggered(countdownSeconds: 20)
        XCTAssertEqual(event.type, .lookAway)
    }
    
    func testTypePropertyForBlink() {
        let event = ReminderEvent.blinkTriggered
        XCTAssertEqual(event.type, .blink)
    }
    
    func testTypePropertyForPosture() {
        let event = ReminderEvent.postureTriggered
        XCTAssertEqual(event.type, .posture)
    }
    
    func testEquality() {
        let event1 = ReminderEvent.lookAwayTriggered(countdownSeconds: 20)
        let event2 = ReminderEvent.lookAwayTriggered(countdownSeconds: 20)
        let event3 = ReminderEvent.lookAwayTriggered(countdownSeconds: 30)
        let event4 = ReminderEvent.blinkTriggered
        let event5 = ReminderEvent.blinkTriggered
        let event6 = ReminderEvent.postureTriggered
        
        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
        XCTAssertNotEqual(event1, event4)
        XCTAssertEqual(event4, event5)
        XCTAssertNotEqual(event4, event6)
    }
    
    func testDifferentCountdownValues() {
        let event1 = ReminderEvent.lookAwayTriggered(countdownSeconds: 0)
        let event2 = ReminderEvent.lookAwayTriggered(countdownSeconds: 10)
        let event3 = ReminderEvent.lookAwayTriggered(countdownSeconds: 60)
        
        XCTAssertNotEqual(event1, event2)
        XCTAssertNotEqual(event2, event3)
        XCTAssertNotEqual(event1, event3)
        
        XCTAssertEqual(event1.type, .lookAway)
        XCTAssertEqual(event2.type, .lookAway)
        XCTAssertEqual(event3.type, .lookAway)
    }
    
    func testNegativeCountdown() {
        let event = ReminderEvent.lookAwayTriggered(countdownSeconds: -5)
        
        if case .lookAwayTriggered(let countdown) = event {
            XCTAssertEqual(countdown, -5)
        } else {
            XCTFail("Expected lookAwayTriggered event")
        }
    }
    
    func testSwitchExhaustivenessWithAllCases() {
        let events: [ReminderEvent] = [
            .lookAwayTriggered(countdownSeconds: 20),
            .blinkTriggered,
            .postureTriggered
        ]
        
        for event in events {
            switch event {
            case .lookAwayTriggered:
                XCTAssertEqual(event.type, .lookAway)
            case .blinkTriggered:
                XCTAssertEqual(event.type, .blink)
            case .postureTriggered:
                XCTAssertEqual(event.type, .posture)
            }
        }
    }
}
