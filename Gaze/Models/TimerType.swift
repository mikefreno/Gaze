//
//  TimerType.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

enum TimerType: String, Codable, CaseIterable, Identifiable {
    case lookAway
    case blink
    case posture

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .lookAway:
            return "Look Away"
        case .blink:
            return "Blink"
        case .posture:
            return "Posture"
        }
    }

    var iconName: String {
        switch self {
        case .lookAway:
            return "eye.fill"
        case .blink:
            return "eye.circle"
        case .posture:
            return "figure.stand"
        }
    }

    var tabIndex: Int {
        switch self {
        case .lookAway:
            return 1
        case .blink:
            return 2
        case .posture:
            return 3
        }
    }

    var tooltipText: String {
        switch self {
        case .lookAway:
            return "Full screen reminder"
        case .blink:
            return "Subtle reminder"
        case .posture:
            return "Subtle reminder"
        }
    }
}
