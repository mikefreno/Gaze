//
//  UserTimer.swift
//  Gaze
//
//  Created by Mike Freno on 1/9/26.
//

import Foundation

/// Represents a user-defined timer with customizable properties
struct UserTimer: Codable, Equatable, Identifiable {
    let id: String
    var type: UserTimerType
    var timeOnScreenSeconds: Int
    var message: String?

    init(
        id: String = UUID().uuidString,
        type: UserTimerType = .subtle,
        timeOnScreenSeconds: Int = 30,
        message: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timeOnScreenSeconds = timeOnScreenSeconds
        self.message = message
    }

    static func == (lhs: UserTimer, rhs: UserTimer) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type
            && lhs.timeOnScreenSeconds == rhs.timeOnScreenSeconds && lhs.message == rhs.message
    }
}

/// Type of user timer - subtle or overlay
enum UserTimerType: String, Codable, CaseIterable, Identifiable {
    case subtle
    case overlay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subtle:
            return "Subtle"
        case .overlay:
            return "Overlay"
        }
    }
}

