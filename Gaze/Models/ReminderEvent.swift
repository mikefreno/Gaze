//
//  ReminderEvent.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

enum ReminderEvent: Equatable {
    case lookAwayTriggered(countdownSeconds: Int)
    case blinkTriggered
    case postureTriggered
    case userTimerTriggered(UserTimer)
    
    var iconName: String {
        switch self {
        case .lookAwayTriggered:
            return "eye.fill"
        case .blinkTriggered:
            return "eye.slash.fill"
        case .postureTriggered:
            return "figure.stand"
        case .userTimerTriggered:
            return "clock.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .lookAwayTriggered:
            return "Look Away"
        case .blinkTriggered:
            return "Blink"
        case .postureTriggered:
            return "Posture"
        case .userTimerTriggered(let timer):
            return timer.title
        }
    }
}

