//
//  SettingsManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Combine
import Foundation
import Observation

@MainActor
@Observable
final class SettingsManager {
    static let shared = SettingsManager()
    
    var settings: AppSettings {
        didSet { _settingsSubject.send(settings) }
    }
    
    @ObservationIgnored
    let _settingsSubject = CurrentValueSubject<AppSettings, Never>(.defaults)
    
    @ObservationIgnored
    private let userDefaults = UserDefaults.standard
    
    @ObservationIgnored
    private let settingsKey = "gazeAppSettings"
    
    @ObservationIgnored
    private var saveCancellable: AnyCancellable?

    @ObservationIgnored
    private let timerConfigKeyPaths: [TimerType: WritableKeyPath<AppSettings, TimerConfiguration>] = [
        .lookAway: \.lookAwayTimer,
        .blink: \.blinkTimer,
        .posture: \.postureTimer,
    ]

    private init() {
        self.settings = Self.loadSettings()
        _settingsSubject.send(settings)
        setupDebouncedSave()
    }

    private func setupDebouncedSave() {
        saveCancellable = _settingsSubject
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "gazeAppSettings") else {
            return .defaults
        }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .defaults
        }
    }

    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {}
    }

    func saveImmediately() {
        save()
    }

    func load() {
        settings = Self.loadSettings()
    }

    func resetToDefaults() {
        settings = .defaults
    }

    func timerConfiguration(for type: TimerType) -> TimerConfiguration {
        guard let keyPath = timerConfigKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        return settings[keyPath: keyPath]
    }

    func updateTimerConfiguration(for type: TimerType, configuration: TimerConfiguration) {
        guard let keyPath = timerConfigKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        settings[keyPath: keyPath] = configuration
    }

    func allTimerConfigurations() -> [TimerType: TimerConfiguration] {
        var configs: [TimerType: TimerConfiguration] = [:]
        for (type, keyPath) in timerConfigKeyPaths {
            configs[type] = settings[keyPath: keyPath]
        }
        return configs
    }
}
