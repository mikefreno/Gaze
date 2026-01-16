//
//  SettingsProviding.swift
//  Gaze
//

import Combine
import Foundation

@MainActor
protocol SettingsProviding: AnyObject, Observable {
    var settings: AppSettings { get set }
    var settingsPublisher: AnyPublisher<AppSettings, Never> { get }
    
    func timerConfiguration(for type: TimerType) -> TimerConfiguration
    func updateTimerConfiguration(for type: TimerType, configuration: TimerConfiguration)
    func allTimerConfigurations() -> [TimerType: TimerConfiguration]
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
