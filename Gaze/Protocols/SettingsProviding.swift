//
//  SettingsProviding.swift
//  Gaze
//

import Combine
import Foundation

@MainActor
protocol TimerSettingsProviding {
    func allTimerSettings() -> [TimerType: (enabled: Bool, intervalMinutes: Int)]
    func isTimerEnabled(for type: TimerType) -> Bool
    func timerIntervalMinutes(for type: TimerType) -> Int
}

@MainActor
protocol SettingsProviding: AnyObject, Observable, TimerSettingsProviding {
    var settings: AppSettings { get set }
    var settingsPublisher: AnyPublisher<AppSettings, Never> { get }

    func save()
    func saveImmediately()
    func load()
    func resetToDefaults()
}

extension SettingsManager: SettingsProviding {
    var settingsPublisher: AnyPublisher<AppSettings, Never> {
        _settingsSubject.eraseToAnyPublisher()
    }
}
