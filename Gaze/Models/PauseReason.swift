//
//  PauseReason.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Foundation

enum PauseReason: Codable, Equatable, Hashable {
    case manual
    case fullscreen
    case idle
    case system
}

extension PauseReason: Sendable {}
