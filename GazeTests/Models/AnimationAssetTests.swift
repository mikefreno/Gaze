//
//  AnimationAssetTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class AnimationAssetTests: XCTestCase {
    
    func testRawValues() {
        XCTAssertEqual(AnimationAsset.blink.rawValue, "blink")
        XCTAssertEqual(AnimationAsset.lookAway.rawValue, "look-away")
        XCTAssertEqual(AnimationAsset.posture.rawValue, "posture")
    }
    
    func testFileNames() {
        XCTAssertEqual(AnimationAsset.blink.fileName, "blink")
        XCTAssertEqual(AnimationAsset.lookAway.fileName, "look-away")
        XCTAssertEqual(AnimationAsset.posture.fileName, "posture")
    }
    
    func testFileNameMatchesRawValue() {
        XCTAssertEqual(AnimationAsset.blink.fileName, AnimationAsset.blink.rawValue)
        XCTAssertEqual(AnimationAsset.lookAway.fileName, AnimationAsset.lookAway.rawValue)
        XCTAssertEqual(AnimationAsset.posture.fileName, AnimationAsset.posture.rawValue)
    }
    
    func testInitFromRawValue() {
        XCTAssertEqual(AnimationAsset(rawValue: "blink"), .blink)
        XCTAssertEqual(AnimationAsset(rawValue: "look-away"), .lookAway)
        XCTAssertEqual(AnimationAsset(rawValue: "posture"), .posture)
        XCTAssertNil(AnimationAsset(rawValue: "invalid"))
    }
    
    func testEquality() {
        XCTAssertEqual(AnimationAsset.blink, AnimationAsset.blink)
        XCTAssertNotEqual(AnimationAsset.blink, AnimationAsset.lookAway)
        XCTAssertNotEqual(AnimationAsset.lookAway, AnimationAsset.posture)
    }
    
    func testAllCasesExist() {
        let blink = AnimationAsset.blink
        let lookAway = AnimationAsset.lookAway
        let posture = AnimationAsset.posture
        
        XCTAssertNotNil(blink)
        XCTAssertNotNil(lookAway)
        XCTAssertNotNil(posture)
    }
}
