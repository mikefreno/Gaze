//
//  TimerConfiguration.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

/// Unified configuration for all timer types (built-in and user)
protocol TimerConfigurationProtocol: Codable, Equatable {
    var intervalSeconds: Int { get }
    var enabled: Bool { get }
    var id: String { get }
}

/// Configuration for a built-in timer
struct BuiltInTimerConfiguration: TimerConfigurationProtocol {
    let intervalSeconds: Int
    let enabled: Bool
    let timerType: TimerType
    
    var id: String {
        return "builtIn:\(timerType.rawValue)"
    }
}

/// Configuration for a user timer
struct UserTimerConfiguration: TimerConfigurationProtocol {
    let intervalSeconds: Int
    let enabled: Bool
    let userTimer: UserTimer
    
    var id: String {
        return "user:\(userTimer.id)"
    }
}
