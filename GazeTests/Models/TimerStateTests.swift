//
//  TimerStateTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class TimerStateTests: XCTestCase {
    
    func testInitialization() {
        let state = TimerState(type: .lookAway, intervalSeconds: 1200)
        
        XCTAssertEqual(state.type, .lookAway)
        XCTAssertEqual(state.remainingSeconds, 1200)
        XCTAssertFalse(state.isPaused)
        XCTAssertTrue(state.isActive)
    }
    
    func testInitializationWithPausedState() {
        let state = TimerState(type: .blink, intervalSeconds: 300, isPaused: true)
        
        XCTAssertEqual(state.type, .blink)
        XCTAssertEqual(state.remainingSeconds, 300)
        XCTAssertTrue(state.isPaused)
        XCTAssertTrue(state.isActive)
    }
    
    func testInitializationWithInactiveState() {
        let state = TimerState(type: .posture, intervalSeconds: 1800, isPaused: false, isActive: false)
        
        XCTAssertEqual(state.type, .posture)
        XCTAssertEqual(state.remainingSeconds, 1800)
        XCTAssertFalse(state.isPaused)
        XCTAssertFalse(state.isActive)
    }
    
    func testMutability() {
        var state = TimerState(type: .lookAway, intervalSeconds: 1200)
        
        state.remainingSeconds = 600
        XCTAssertEqual(state.remainingSeconds, 600)
        
        state.isPaused = true
        XCTAssertTrue(state.isPaused)
        
        state.isActive = false
        XCTAssertFalse(state.isActive)
    }
    
    func testEquality() {
        let state1 = TimerState(type: .lookAway, intervalSeconds: 1200)
        let state2 = TimerState(type: .lookAway, intervalSeconds: 1200)
        let state3 = TimerState(type: .blink, intervalSeconds: 1200)
        let state4 = TimerState(type: .lookAway, intervalSeconds: 600)
        
        XCTAssertEqual(state1, state2)
        XCTAssertNotEqual(state1, state3)
        XCTAssertNotEqual(state1, state4)
    }
    
    func testEqualityWithDifferentPausedState() {
        let state1 = TimerState(type: .lookAway, intervalSeconds: 1200, isPaused: false)
        let state2 = TimerState(type: .lookAway, intervalSeconds: 1200, isPaused: true)
        
        XCTAssertNotEqual(state1, state2)
    }
    
    func testEqualityWithDifferentActiveState() {
        let state1 = TimerState(type: .lookAway, intervalSeconds: 1200, isActive: true)
        let state2 = TimerState(type: .lookAway, intervalSeconds: 1200, isActive: false)
        
        XCTAssertNotEqual(state1, state2)
    }
    
    func testZeroRemainingSeconds() {
        let state = TimerState(type: .lookAway, intervalSeconds: 0)
        XCTAssertEqual(state.remainingSeconds, 0)
    }
    
    func testNegativeRemainingSeconds() {
        var state = TimerState(type: .lookAway, intervalSeconds: 10)
        state.remainingSeconds = -5
        XCTAssertEqual(state.remainingSeconds, -5)
    }
    
    func testLargeIntervalSeconds() {
        let state = TimerState(type: .posture, intervalSeconds: 86400)
        XCTAssertEqual(state.remainingSeconds, 86400)
    }
}
