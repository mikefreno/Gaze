//
//  TimeProviding.swift
//  Gaze
//
//  Protocol for abstracting time sources to enable deterministic testing.
//

import Foundation

/// Protocol for providing current time, enabling deterministic tests.
protocol TimeProviding: Sendable {
    /// Returns the current date/time
    func now() -> Date
}

/// Default implementation that uses the system clock
struct SystemTimeProvider: TimeProviding {
    func now() -> Date {
        Date()
    }
}
