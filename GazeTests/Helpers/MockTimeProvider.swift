//
//  MockTimeProvider.swift
//  GazeTests
//
//  Mock time provider for deterministic timer testing.
//

import Foundation
@testable import Gaze

/// A mock time provider for deterministic testing.
/// Allows manual control over time in tests.
final class MockTimeProvider: TimeProviding, @unchecked Sendable {
    private var currentTime: Date
    
    init(startTime: Date = Date()) {
        self.currentTime = startTime
    }
    
    func now() -> Date {
        currentTime
    }
    
    /// Advances time by the specified interval
    func advance(by interval: TimeInterval) {
        currentTime = currentTime.addingTimeInterval(interval)
    }
    
    /// Sets the current time to a specific date
    func setTime(_ date: Date) {
        currentTime = date
    }
}
