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
    
    var type: TimerType {
        switch self {
        case .lookAwayTriggered:
            return .lookAway
        case .blinkTriggered:
            return .blink
        case .postureTriggered:
            return .posture
        }
    }
}
