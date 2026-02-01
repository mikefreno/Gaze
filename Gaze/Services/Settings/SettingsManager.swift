//
//  SettingsManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Combine
import Foundation
import Observation

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
            if let migrated = migrateLegacySettings(from: data) {
                return migrated
            }
            return .defaults
        }
    }

    private static func migrateLegacySettings(from data: Data) -> AppSettings? {
        guard let legacy = try? JSONDecoder().decode(LegacyAppSettings.self, from: data) else {
            return nil
        }

        var settings = AppSettings(
            lookAwayEnabled: legacy.lookAwayEnabled,
            lookAwayIntervalMinutes: legacy.lookAwayIntervalMinutes,
            lookAwayCountdownSeconds: DefaultSettingsBuilder.lookAwayCountdownSeconds,
            blinkEnabled: legacy.blinkEnabled,
            blinkIntervalMinutes: legacy.blinkIntervalMinutes,
            postureEnabled: legacy.postureEnabled,
            postureIntervalMinutes: legacy.postureIntervalMinutes,
            userTimers: legacy.userTimers,
            subtleReminderSize: legacy.subtleReminderSize,
            smartMode: legacy.smartMode,
            enforceModeEyeBoxWidthFactor: legacy.enforceModeEyeBoxWidthFactor,
            enforceModeEyeBoxHeightFactor: legacy.enforceModeEyeBoxHeightFactor,
            enforceModeCalibration: legacy.enforceModeCalibration,
            hasCompletedOnboarding: legacy.hasCompletedOnboarding,
            launchAtLogin: legacy.launchAtLogin,
            playSounds: legacy.playSounds
        )

        for index in settings.userTimers.indices {
            if settings.userTimers[index].type == .overlay {
                settings.userTimers[index].enforceModeEnabled = true
            }
        }
        return settings
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

private struct LegacyAppSettings: Codable {
    let lookAwayEnabled: Bool
    let lookAwayIntervalMinutes: Int
    let blinkEnabled: Bool
    let blinkIntervalMinutes: Int
    let postureEnabled: Bool
    let postureIntervalMinutes: Int
    let userTimers: [UserTimer]
    let subtleReminderSize: ReminderSize
    let smartMode: SmartModeSettings
    let enforceModeEyeBoxWidthFactor: Double
    let enforceModeEyeBoxHeightFactor: Double
    let enforceModeCalibration: EnforceModeCalibration?
    let hasCompletedOnboarding: Bool
    let launchAtLogin: Bool
    let playSounds: Bool
}
