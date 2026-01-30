//
//  AnimationAsset.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import Foundation

enum AnimationAsset: String {
    case blink = "blink"
    case lookAway = "look-away"
    case posture = "posture"
    case ring = "ring"

    var fileName: String {
        return self.rawValue
    }
}
