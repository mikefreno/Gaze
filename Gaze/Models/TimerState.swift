//
//  TimerState.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

struct TimerState: Equatable {
    let type: TimerType
    var remainingSeconds: Int
    var isPaused: Bool
    var isActive: Bool
    var targetDate: Date

    init(type: TimerType, intervalSeconds: Int, isPaused: Bool = false, isActive: Bool = true) {
        self.type = type
        self.remainingSeconds = intervalSeconds
        self.isPaused = isPaused
        self.isActive = isActive
        self.targetDate = Date().addingTimeInterval(Double(intervalSeconds))
    }

    static func == (lhs: TimerState, rhs: TimerState) -> Bool {
        lhs.type == rhs.type && lhs.remainingSeconds == rhs.remainingSeconds
            && lhs.isPaused == rhs.isPaused && lhs.isActive == rhs.isActive
            && lhs.targetDate.timeIntervalSince1970.rounded()
                == rhs.targetDate.timeIntervalSince1970.rounded()
    }
}
