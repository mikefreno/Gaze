//
//  SettingsSection.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Foundation

enum SettingsSection: Int, CaseIterable, Identifiable {
    case general = 0
    case lookAway = 1
    case blink = 2
    case posture = 3
    case userTimers = 4
    #if DEBUG
        case enforceMode = 5
    #endif
    case smartMode = 6

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .lookAway: return "Look Away"
        case .blink: return "Blink"
        case .posture: return "Posture"
        #if DEBUG
            case .enforceMode: return "Enforce Mode"
        #endif
        case .userTimers: return "User Timers"
        case .smartMode: return "Smart Mode"
        }
    }

    var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .lookAway: return "eye.fill"
        case .blink: return "eye.circle.fill"
        case .posture: return "figure.stand"
        #if DEBUG
            case .enforceMode: return "video.fill"
        #endif
        case .userTimers: return "plus.circle"
        case .smartMode: return "brain.fill"
        }
    }
}
