//
//  LoggingManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import Foundation
import os.log

nonisolated private let loggingSubsystem = "com.mikefreno.Gaze"
nonisolated private let isLoggingEnabled: Bool = {
    #if DEBUG
        return true
    #else
        return false
    #endif
}()

/// A centralized logging manager that provides structured, subsystem-aware logging
/// for the Gaze application to ensure logs are captured by the run script.
final class LoggingManager: @unchecked Sendable {
    static let shared = LoggingManager()

    // MARK: - Private Properties

    private let subsystem = loggingSubsystem

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
    }

    // MARK: - Public Methods

    func configureLogging() {
        //nothing needed for now
    }

    /// Convenience method for debug logging
    func debug(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.debug("\(message, privacy: .public)")
    }

    /// Convenience method for info logging
    func info(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.info("\(message, privacy: .public)")
    }

    /// Convenience method for error logging
    func error(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.error("\(message, privacy: .public)")
    }

    /// Convenience method for warning logging
    func warning(_ message: String, category: String = "General") {
        guard isLoggingEnabled else { return }
        let logger = Logger(subsystem: subsystem, category: category)
        logger.warning("\(message, privacy: .public)")
    }
}

/// Log an info message using the shared LoggingManager
nonisolated public func logInfo(_ message: String, category: String = "General") {
    guard isLoggingEnabled else { return }
    let logger = Logger(subsystem: loggingSubsystem, category: category)
    logger.info("\(message, privacy: .public)")
}

/// Log a debug message using the shared LoggingManager
nonisolated public func logDebug(_ message: String, category: String = "General") {
    guard isLoggingEnabled else { return }
    let logger = Logger(subsystem: loggingSubsystem, category: category)
    logger.debug("\(message, privacy: .public)")
}

/// Log an error message using the shared LoggingManager
nonisolated public func logError(_ message: String, category: String = "General") {
    guard isLoggingEnabled else { return }
    let logger = Logger(subsystem: loggingSubsystem, category: category)
    logger.error("\(message, privacy: .public)")
}

/// Log a warning message using the shared LoggingManager
nonisolated public func logWarning(_ message: String, category: String = "General") {
    guard isLoggingEnabled else { return }
    let logger = Logger(subsystem: loggingSubsystem, category: category)
    logger.warning("\(message, privacy: .public)")
}

// MARK: - Additional Helper Functions

/// Log a verbose message (only enabled in DEBUG builds)
nonisolated public func logVerbose(_ message: String, category: String = "General") {
    #if DEBUG
        let logger = Logger(subsystem: loggingSubsystem, category: category)
        logger.debug("\(message, privacy: .public)")
    #endif
}
