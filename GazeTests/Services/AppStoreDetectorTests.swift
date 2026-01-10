//
//  AppStoreDetectorTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/10/26.
//

@testable import Gaze
import Testing

struct AppStoreDetectorTests {
    
    @Test func isAppStoreVersionReturnsFalseInDebug() {
        // In test/debug builds, should always return false
        #expect(AppStoreDetector.isAppStoreVersion == false)
    }
}
