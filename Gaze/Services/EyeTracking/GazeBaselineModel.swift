//
//  GazeBaselineModel.swift
//  Gaze
//
//  Created by Mike Freno on 1/31/26.
//

import Foundation

public final class GazeBaselineModel: @unchecked Sendable {
    public struct Baseline: Sendable {
        let horizontal: Double
        let vertical: Double
        let sampleCount: Int
    }

    private let lock = NSLock()
    private var horizontal: Double?
    private var vertical: Double?
    private var sampleCount: Int = 0

    public func reset() {
        lock.lock()
        horizontal = nil
        vertical = nil
        sampleCount = 0
        lock.unlock()
    }

    public func update(horizontal: Double, vertical: Double, smoothing: Double) {
        lock.lock()
        defer { lock.unlock() }

        if let existingH = self.horizontal, let existingV = self.vertical {
            self.horizontal = existingH + (horizontal - existingH) * smoothing
            self.vertical = existingV + (vertical - existingV) * smoothing
        } else {
            self.horizontal = horizontal
            self.vertical = vertical
        }
        sampleCount += 1
    }

    public func current(defaultH: Double, defaultV: Double) -> Baseline {
        lock.lock()
        defer { lock.unlock() }

        return Baseline(
            horizontal: horizontal ?? defaultH,
            vertical: vertical ?? defaultV,
            sampleCount: sampleCount
        )
    }
}
