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

    @Published var settings: AppSettings

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "gazeAppSettings"
    private var saveCancellable: AnyCancellable?

    private let timerConfigKeyPaths: [TimerType: WritableKeyPath<AppSettings, TimerConfiguration>] =
        [
            .lookAway: \.lookAwayTimer,
            .blink: \.blinkTimer,
            .posture: \.postureTimer,
        ]

    private init() {
        #if DEBUG
            // Clear settings on every development build
            UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        #endif
        self.settings = Self.loadSettings()
        #if DEBUG
            validateTimerConfigMappings()
        #endif
        setupDebouncedSave()
    }

    deinit {
        saveCancellable?.cancel()
        // Final save will be called by AppDelegate.applicationWillTerminate
    }

    private func setupDebouncedSave() {
        saveCancellable =
            $settings
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.save()
            }
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "gazeAppSettings"),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return .defaults
        }
        return settings
    }

    /// Saves settings to UserDefaults.
    /// Note: Settings are automatically saved via debouncing (500ms delay) when the `settings` property changes.
    /// This method is also called explicitly during app termination to ensure final state is persisted.
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

    /// Returns all timer configurations as a dictionary
    func allTimerConfigurations() -> [TimerType: TimerConfiguration] {
        var configs: [TimerType: TimerConfiguration] = [:]
        for (type, keyPath) in timerConfigKeyPaths {
            configs[type] = settings[keyPath: keyPath]
        }
        return configs
    }

    /// Validates that all timer types have configuration mappings
    private func validateTimerConfigMappings() {
        let allTypes = Set(TimerType.allCases)
        let mappedTypes = Set(timerConfigKeyPaths.keys)

        let missing = allTypes.subtracting(mappedTypes)
        if !missing.isEmpty {
            preconditionFailure("Missing timer configuration mappings for: \(missing)")
        }
    }

    /// Detects and caches the App Store version status.
    /// This should be called once at app launch to avoid async checks throughout the app.
    func detectAppStoreVersion() async {
        let isAppStore = await AppStoreDetector.isAppStoreVersion()
        await MainActor.run {
            settings.isAppStoreVersion = isAppStore
        }
    }
}
