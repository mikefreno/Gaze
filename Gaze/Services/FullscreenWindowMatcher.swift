//
//  FullscreenWindowMatcher.swift
//  Gaze
//
//  Created by Mike Freno on 1/29/26.
//

import CoreGraphics

struct FullscreenWindowMatcher {
    func isFullscreen(windowBounds: CGRect, screenFrames: [CGRect], tolerance: CGFloat = 1) -> Bool {
        screenFrames.contains { matches(windowBounds, screenFrame: $0, tolerance: tolerance) }
    }

    private func matches(_ windowBounds: CGRect, screenFrame: CGRect, tolerance: CGFloat) -> Bool {
        abs(windowBounds.width - screenFrame.width) < tolerance
            && abs(windowBounds.height - screenFrame.height) < tolerance
            && abs(windowBounds.origin.x - screenFrame.origin.x) < tolerance
            && abs(windowBounds.origin.y - screenFrame.origin.y) < tolerance
    }
}
