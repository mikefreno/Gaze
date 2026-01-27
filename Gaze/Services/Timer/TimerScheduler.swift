//
//  TimerScheduler.swift
//  Gaze
//
//  Schedules timer ticks for TimerEngine.
//

import Combine
import Foundation

protocol TimerSchedulerDelegate: AnyObject {
    func schedulerDidTick(_ scheduler: TimerScheduler)
}

@MainActor
final class TimerScheduler {
    weak var delegate: TimerSchedulerDelegate?

    private var timerSubscription: AnyCancellable?
    private let timeProvider: TimeProviding

    init(timeProvider: TimeProviding) {
        self.timeProvider = timeProvider
    }

    var isRunning: Bool {
        timerSubscription != nil
    }

    func start() {
        guard timerSubscription == nil else { return }
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.delegate?.schedulerDidTick(self)
            }
    }

    func stop() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
}
