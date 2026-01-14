//
//  TimerState.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

struct TimerState: Equatable, Hashable {
    let identifier: TimerIdentifier
    var remainingSeconds: Int
    var isPaused: Bool
    var pauseReasons: Set<PauseReason>
    var isActive: Bool
    var targetDate: Date
    let originalIntervalSeconds: Int

    init(identifier: TimerIdentifier, intervalSeconds: Int, isPaused: Bool = false, isActive: Bool = true) {
        self.identifier = identifier
        self.remainingSeconds = intervalSeconds
        self.isPaused = isPaused
        self.pauseReasons = []
        self.isActive = isActive
        self.targetDate = Date().addingTimeInterval(Double(intervalSeconds))
        self.originalIntervalSeconds = intervalSeconds
    }
}
