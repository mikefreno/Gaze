//
//  TimerTypeTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class TimerTypeTests: XCTestCase {
    
    func testAllCases() {
        let allCases = TimerType.allCases
        XCTAssertEqual(allCases.count, 3)
        XCTAssertTrue(allCases.contains(.lookAway))
        XCTAssertTrue(allCases.contains(.blink))
        XCTAssertTrue(allCases.contains(.posture))
    }
    
    func testRawValues() {
        XCTAssertEqual(TimerType.lookAway.rawValue, "lookAway")
        XCTAssertEqual(TimerType.blink.rawValue, "blink")
        XCTAssertEqual(TimerType.posture.rawValue, "posture")
    }
    
    func testDisplayNames() {
        XCTAssertEqual(TimerType.lookAway.displayName, "Look Away")
        XCTAssertEqual(TimerType.blink.displayName, "Blink")
        XCTAssertEqual(TimerType.posture.displayName, "Posture")
    }
    
    func testIconNames() {
        XCTAssertEqual(TimerType.lookAway.iconName, "eye.fill")
        XCTAssertEqual(TimerType.blink.iconName, "eye.circle")
        XCTAssertEqual(TimerType.posture.iconName, "figure.stand")
    }
    
    func testIdentifiable() {
        XCTAssertEqual(TimerType.lookAway.id, "lookAway")
        XCTAssertEqual(TimerType.blink.id, "blink")
        XCTAssertEqual(TimerType.posture.id, "posture")
    }
    
    func testCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        for timerType in TimerType.allCases {
            let encoded = try encoder.encode(timerType)
            let decoded = try decoder.decode(TimerType.self, from: encoded)
            XCTAssertEqual(decoded, timerType)
        }
    }
    
    func testEquality() {
        XCTAssertEqual(TimerType.lookAway, TimerType.lookAway)
        XCTAssertNotEqual(TimerType.lookAway, TimerType.blink)
        XCTAssertNotEqual(TimerType.blink, TimerType.posture)
    }
    
    func testInitFromRawValue() {
        XCTAssertEqual(TimerType(rawValue: "lookAway"), .lookAway)
        XCTAssertEqual(TimerType(rawValue: "blink"), .blink)
        XCTAssertEqual(TimerType(rawValue: "posture"), .posture)
        XCTAssertNil(TimerType(rawValue: "invalid"))
    }
}
