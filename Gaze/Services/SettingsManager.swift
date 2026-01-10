//
//  SettingsManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Combine
import Foundation

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    @Published var settings: AppSettings {
        didSet {
            save()
        }
    }

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "gazeAppSettings"

    private init() {
        #if DEBUG
            // Clear settings on every development build
            UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        #endif
        self.settings = Self.loadSettings()
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "gazeAppSettings"),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(settings) else {
            print("Failed to encode settings")
            return
        }
        userDefaults.set(data, forKey: settingsKey)
    }

    func load() {
        settings = Self.loadSettings()
    }

    func resetToDefaults() {
        settings = .defaults
    }

    func timerConfiguration(for type: TimerType) -> TimerConfiguration {
        switch type {
        case .lookAway:
            return settings.lookAwayTimer
        case .blink:
            return settings.blinkTimer
        case .posture:
            return settings.postureTimer
        }
    }

    func updateTimerConfiguration(for type: TimerType, configuration: TimerConfiguration) {
        switch type {
        case .lookAway:
            settings.lookAwayTimer = configuration
        case .blink:
            settings.blinkTimer = configuration
        case .posture:
            settings.postureTimer = configuration
        }
    }
}
