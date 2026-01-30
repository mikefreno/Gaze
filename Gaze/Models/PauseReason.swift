//
//  PauseReason.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Foundation

enum PauseReason: nonisolated Codable, nonisolated Sendable, nonisolated Equatable, nonisolated Hashable {
    case manual
    case fullscreen
    case idle
    case system

    nonisolated static func == (lhs: PauseReason, rhs: PauseReason) -> Bool {
        switch (lhs, rhs) {
        case (.manual, .manual),
            (.fullscreen, .fullscreen),
            (.idle, .idle),
            (.system, .system):
            return true
        default:
            return false
        }
    }

    nonisolated func hash(into hasher: inout Hasher) {
        switch self {
        case .manual:
            hasher.combine(0)
        case .fullscreen:
            hasher.combine(1)
        case .idle:
            hasher.combine(2)
        case .system:
            hasher.combine(3)
        }
    }
}

