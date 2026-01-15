//
//  TimeProviding.swift
//  Gaze
//
//  Protocol for abstracting time sources to enable deterministic testing.
//

import Foundation

/// Protocol for providing current time, enabling deterministic tests.
protocol TimeProviding {
    /// Returns the current date/time
    func now() -> Date
}

/// Default implementation that uses the system clock
struct SystemTimeProvider: TimeProviding {
    func now() -> Date {
        Date()
    }
}

/// Test implementation that allows manual time control
final class MockTimeProvider: TimeProviding {
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
