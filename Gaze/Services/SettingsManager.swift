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
    private let timerConfigKeyPaths: [TimerType: WritableKeyPath<AppSettings, Bool>] = [
        .lookAway: \.lookAwayEnabled,
        .blink: \.blinkEnabled,
        .posture: \.postureEnabled,
    ]

    @ObservationIgnored
    private let intervalKeyPaths: [TimerType: WritableKeyPath<AppSettings, Int>] = [
        .lookAway: \.lookAwayIntervalMinutes,
        .blink: \.blinkIntervalMinutes,
        .posture: \.postureIntervalMinutes,
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

    func isTimerEnabled(for type: TimerType) -> Bool {
        guard let keyPath = timerConfigKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        return settings[keyPath: keyPath]
    }

    func updateTimerEnabled(for type: TimerType, enabled: Bool) {
        guard let keyPath = timerConfigKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        settings[keyPath: keyPath] = enabled
    }

    func timerIntervalMinutes(for type: TimerType) -> Int {
        guard let keyPath = intervalKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        return settings[keyPath: keyPath]
    }

    func updateTimerInterval(for type: TimerType, minutes: Int) {
        guard let keyPath = intervalKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        settings[keyPath: keyPath] = minutes
    }

    func allTimerSettings() -> [TimerType: (enabled: Bool, intervalMinutes: Int)] {
        TimerType.allCases.reduce(into: [:]) { result, type in
            result[type] = (enabled: isTimerEnabled(for: type), intervalMinutes: timerIntervalMinutes(for: type))
        }
    }
}
