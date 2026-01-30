//
//  TimerEngineProviding.swift
//  Gaze
//
//  Protocol abstraction for TimerEngine to enable dependency injection and testing.
//

import Combine
import Foundation

/// Protocol that defines the interface for timer engine functionality.
/// This abstraction allows for dependency injection and easy mocking in tests.
protocol TimerEngineProviding: AnyObject, ObservableObject {
    /// Current timer states for all active timers
    var timerStates: [TimerIdentifier: TimerState] { get }
    
    /// Publisher for timer states changes
    var timerStatesPublisher: Published<[TimerIdentifier: TimerState]>.Publisher { get }
    
    /// Currently active reminder, if any
    var activeReminder: ReminderEvent? { get set }
    
    /// Publisher for active reminder changes
    var activeReminderPublisher: Published<ReminderEvent?>.Publisher { get }
    
    /// Starts all enabled timers
    func start()
    
    /// Stops all timers
    func stop()
    
    /// Pauses all timers
    func pause()
    
    /// Resumes all timers
    func resume()
    
    /// Pauses a specific timer
    func pauseTimer(identifier: TimerIdentifier)
    
    /// Resumes a specific timer
    func resumeTimer(identifier: TimerIdentifier)
    
    /// Skips the next reminder for a specific timer and resets it
    func skipNext(identifier: TimerIdentifier)
    
    /// Dismisses the current active reminder
    func dismissReminder()
    
    /// Triggers a reminder for a specific timer
    func triggerReminder(for identifier: TimerIdentifier)
    
    /// Gets the time remaining for a specific timer
    func getTimeRemaining(for identifier: TimerIdentifier) -> TimeInterval
    
    /// Gets a formatted string of time remaining for a specific timer
    func getFormattedTimeRemaining(for identifier: TimerIdentifier) -> String
    
    /// Checks if a timer is currently paused
    func isTimerPaused(_ identifier: TimerIdentifier) -> Bool
    
    /// Sets up smart mode with fullscreen and idle detection services
    func setupSmartMode(
        fullscreenService: FullscreenDetectionService?,
        idleService: IdleMonitoringService?
    )
}

// MARK: - TimerEngine conformance

extension TimerEngine: TimerEngineProviding {
    var timerStatesPublisher: Published<[TimerIdentifier: TimerState]>.Publisher {
        $timerStates
    }
    
    var activeReminderPublisher: Published<ReminderEvent?>.Publisher {
        $activeReminder
    }
}
