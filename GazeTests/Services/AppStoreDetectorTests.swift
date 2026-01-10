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

    @Test func isTestFlightReturnsFalseInDebug() {
        // In test/debug builds, should always return false
        #expect(AppStoreDetector.isTestFlight == false)
    }

    @Test func receiptValidationHandlesMissingReceipt() {
        // When there's no receipt (development build), should return false
        // This is implicitly tested by isAppStoreVersionReturnsFalseInDebug
        // but we're documenting the expected behavior
        #expect(AppStoreDetector.isAppStoreVersion == false)
    }
}
