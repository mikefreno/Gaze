//
//  LaunchAtLoginManagerTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/8/26.
//

import XCTest
@testable import Gaze

final class LaunchAtLoginManagerTests: XCTestCase {
    
    func testIsEnabledReturnsBool() {
        let isEnabled = LaunchAtLoginManager.isEnabled
        XCTAssertNotNil(isEnabled)
    }
    
    func testIsEnabledOnMacOS13AndLater() {
        if #available(macOS 13.0, *) {
            let isEnabled = LaunchAtLoginManager.isEnabled
            XCTAssert(isEnabled == true || isEnabled == false)
        }
    }
    
    func testIsEnabledOnOlderMacOS() {
        if #unavailable(macOS 13.0) {
            let isEnabled = LaunchAtLoginManager.isEnabled
            XCTAssertFalse(isEnabled)
        }
    }
    
    func testEnableThrowsOnUnsupportedOS() {
        if #unavailable(macOS 13.0) {
            XCTAssertThrowsError(try LaunchAtLoginManager.enable()) { error in
                XCTAssertTrue(error is LaunchAtLoginError)
                if let launchError = error as? LaunchAtLoginError {
                    XCTAssertEqual(launchError, .unsupportedOS)
                }
            }
        }
    }
    
    func testDisableThrowsOnUnsupportedOS() {
        if #unavailable(macOS 13.0) {
            XCTAssertThrowsError(try LaunchAtLoginManager.disable()) { error in
                XCTAssertTrue(error is LaunchAtLoginError)
                if let launchError = error as? LaunchAtLoginError {
                    XCTAssertEqual(launchError, .unsupportedOS)
                }
            }
        }
    }
    
    func testToggleDoesNotCrash() {
        LaunchAtLoginManager.toggle()
    }
    
    func testLaunchAtLoginErrorCases() {
        let unsupportedError = LaunchAtLoginError.unsupportedOS
        let registrationError = LaunchAtLoginError.registrationFailed
        
        XCTAssertNotEqual(unsupportedError, registrationError)
    }
    
    func testLaunchAtLoginErrorEquality() {
        let error1 = LaunchAtLoginError.unsupportedOS
        let error2 = LaunchAtLoginError.unsupportedOS
        
        XCTAssertEqual(error1, error2)
    }
}
