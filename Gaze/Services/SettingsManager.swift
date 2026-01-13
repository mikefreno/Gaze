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
        self.settings = Self.loadSettings()
        #if DEBUG
            validateTimerConfigMappings()
        #endif
        setupDebouncedSave()
    }

    deinit {
        saveCancellable?.cancel()
        // Final save is called by AppDelegate.applicationWillTerminate
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
        guard let data = UserDefaults.standard.data(forKey: "gazeAppSettings") else {
            #if DEBUG
            print("ℹ️ No saved settings found, using defaults")
            #endif
            return .defaults
        }
        
        do {
            let settings = try JSONDecoder().decode(AppSettings.self, from: data)
            #if DEBUG
            print("✅ Settings loaded successfully (\(data.count) bytes)")
            #endif
            return settings
        } catch {
            print("⚠️ Failed to decode settings, using defaults: \(error.localizedDescription)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("  Missing key: \(key.stringValue) at path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("  Type mismatch for type: \(type) at path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("  Value not found for type: \(type) at path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("  Data corrupted at path: \(context.codingPath)")
                @unknown default:
                    print("  Unknown decoding error: \(decodingError)")
                }
            }
            return .defaults
        }
    }

    /// Saves settings to UserDefaults.
    /// Note: Settings are automatically saved via debouncing (500ms delay) when the `settings` property changes.
    /// This method is also called explicitly during app termination to ensure final state is persisted.
    func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
            
            #if DEBUG
            print("✅ Settings saved successfully (\(data.count) bytes)")
            #endif
        } catch {
            print("❌ Failed to encode settings: \(error.localizedDescription)")
            if let encodingError = error as? EncodingError {
                switch encodingError {
                case .invalidValue(let value, let context):
                    print("  Invalid value: \(value) at path: \(context.codingPath)")
                default:
                    print("  Encoding error: \(encodingError)")
                }
            }
        }
    }

    /// Forces immediate save and ensures UserDefaults are persisted to disk.
    /// Use this for critical save points like app termination or system sleep.
    func saveImmediately() {
        save()
        // Cancel any pending debounced saves
        saveCancellable?.cancel()
        setupDebouncedSave()
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
