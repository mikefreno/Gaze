//
//  LoggingManager.swift
//  Gaze
//
//  Created by [Your Name] on [Date].
//

import Foundation
import os.log

#if DEBUG
let isLoggingEnabled = true
#else
let isLoggingEnabled = false
#endif

/// A centralized logging manager that provides structured, subsystem-aware logging
/// for the Gaze application to ensure logs are captured by the run script.
final class LoggingManager {
    static let shared = LoggingManager()

    // MARK: - Private Properties

    private let subsystem = "com.mikefreno.Gaze"

    // MARK: - Public Loggers

    /// Logger for general application events
    let appLogger = Logger(subsystem: "com.mikefreno.Gaze", category: "Application")

    /// Logger for timer-related events
    let timerLogger = Logger(subsystem: "com.mikefreno.Gaze", category: "TimerEngine")

    /// Logger for settings and configuration changes
    let settingsLogger = Logger(subsystem: "com.mikefreno.Gaze", category: "Settings")

    /// Logger for smart mode functionality
    let smartModeLogger = Logger(subsystem: "com.mikefreno.Gaze", category: "SmartMode")

    /// Logger for UI and window management events
    let uiLogger = Logger(subsystem: "com.mikefreno.Gaze", category: "UI")

    /// Logger for system events (sleep/wake)
    let systemLogger = Logger(subsystem: "com.mikefreno.Gaze", category: "System")

    // MARK: - Initialization

    private init() {
        // Private initializer to enforce singleton pattern
    }

    // MARK: - Public Methods

    /// Configure the logging system for verbose output when needed
    func configureLogging() {
        // For now, we'll use standard OSLog behavior.
        // This can be extended in the future to support runtime log level changes.
    }

    /// Convenience method for debug logging
    func debug(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.debug("\(message)")
    }

    /// Convenience method for info logging
    func info(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.info("\(message)")
    }

    /// Convenience method for error logging
    func error(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.error("\(message)")
    }

    /// Convenience method for warning logging
    func warning(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.warning("\(message)")
    }
}

