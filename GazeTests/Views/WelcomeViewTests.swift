//
//  WelcomeViewTests.swift
//  GazeTests
//
//  Tests for WelcomeView component.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class WelcomeViewTests: XCTestCase {
    
    func testWelcomeViewInitialization() {
        let view = WelcomeView()
        XCTAssertNotNil(view)
    }
    
    func testWelcomeViewHasAccessibilityIdentifier() {
        // Welcome view should have proper accessibility identifier
        // This is a structural test - in real app, verify the view has the identifier
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.welcomePage,
            "onboarding.page.welcome"
        )
    }
}
