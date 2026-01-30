//
//  TimerState.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

struct TimerState: Equatable, Hashable, Sendable {
    let identifier: TimerIdentifier
    var remainingSeconds: Int
    var isPaused: Bool
    var pauseReasons: Set<PauseReason>
    var isActive: Bool
    let originalIntervalSeconds: Int
    let lastResetDate: Date

    func targetDate(using timeProvider: TimeProviding) -> Date {
        lastResetDate.addingTimeInterval(Double(originalIntervalSeconds))
    }

    var remainingDuration: TimeInterval {
        TimeInterval(remainingSeconds)
    }

    func isExpired(using timeProvider: TimeProviding) -> Bool {
        targetDate(using: timeProvider) <= timeProvider.now()
    }

    var formattedDuration: String {
        remainingDuration.formatAsTimerDurationFull()
    }

    mutating func reset(intervalSeconds: Int? = nil, keepPaused: Bool = true) {
        let newIntervalSeconds = intervalSeconds ?? originalIntervalSeconds
        let newPauseReasons = keepPaused ? pauseReasons : []
        self = TimerStateBuilder.make(
            identifier: identifier,
            intervalSeconds: newIntervalSeconds,
            isPaused: keepPaused ? isPaused : false,
            pauseReasons: newPauseReasons,
            isActive: isActive
        )
    }
}

enum TimerStateBuilder: Sendable {
    static func make(
        identifier: TimerIdentifier,
        intervalSeconds: Int,
        isPaused: Bool = false,
        pauseReasons: Set<PauseReason> = [],
        isActive: Bool = true,
        lastResetDate: Date = Date()
    ) -> TimerState {
        TimerState(
            identifier: identifier,
            remainingSeconds: intervalSeconds,
            isPaused: isPaused,
            pauseReasons: pauseReasons,
            isActive: isActive,
            originalIntervalSeconds: intervalSeconds,
            lastResetDate: lastResetDate
        )
    }
}
