//
//  SetupPresentation.swift
//  Gaze
//
//  Created by Mike Freno on 1/30/26.
//

import Foundation

enum SetupPresentation {
    case window
    case card

    var isWindow: Bool { self == .window }
    var isCard: Bool { self == .card }
}
