//
//  TimerIdentifier.swift
//  Gaze
//
//  Created by Mike Freno on 1/12/26.
//

import Foundation

/// Unified identifier for both built-in and user-defined timers
enum TimerIdentifier: Hashable, Codable, Sendable {
    case builtIn(TimerType)
    case user(id: String)
    
    var displayName: String {
        switch self {
        case .builtIn(let type):
            return type.displayName
        case .user:
            // Will be looked up from settings in views
            return "User Timer"
        }
    }
    
    var iconName: String {
        switch self {
        case .builtIn(let type):
            return type.iconName
        case .user:
            return "clock.fill"
        }
    }
}
