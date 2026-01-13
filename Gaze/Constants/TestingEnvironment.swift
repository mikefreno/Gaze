//
//  TestingEnvironment.swift
//  Gaze
//
//  Created by OpenCode on 1/13/26.
//

import Foundation

/// Detects and manages testing environment states
enum TestingEnvironment {
    /// Check if app is running in UI testing mode
    static var isUITesting: Bool {
        return ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }
    
    /// Check if app should skip onboarding
    static var shouldSkipOnboarding: Bool {
        return ProcessInfo.processInfo.arguments.contains("--skip-onboarding")
    }
    
    /// Check if app should reset onboarding
    static var shouldResetOnboarding: Bool {
        return ProcessInfo.processInfo.arguments.contains("--reset-onboarding")
    }
    
    /// Check if running in any test mode (unit tests or UI tests)
    static var isAnyTestMode: Bool {
        return isUITesting || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
    
    #if DEBUG
    /// Check if dev triggers should be visible
    static var shouldShowDevTriggers: Bool {
        return isUITesting || isAnyTestMode
    }
    #endif
}
