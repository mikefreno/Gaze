//
//  CompletionViewTests.swift
//  GazeTests
//
//  Tests for CompletionView component.
//

import SwiftUI
import XCTest
@testable import Gaze

@MainActor
final class CompletionViewTests: XCTestCase {
    
    func testCompletionViewInitialization() {
        let view = CompletionView()
        XCTAssertNotNil(view)
    }
    
    func testCompletionAccessibilityIdentifier() {
        XCTAssertEqual(
            AccessibilityIdentifiers.Onboarding.completionPage,
            "onboarding.page.completion"
        )
    }
}
