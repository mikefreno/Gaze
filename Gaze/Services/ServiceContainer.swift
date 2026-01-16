//
//  ServiceContainer.swift
//  Gaze
//
//  Dependency injection container for managing service instances.
//

import Combine
import Foundation

/// A simple dependency injection container for managing service instances.
/// Supports both production and test configurations.
@MainActor
final class ServiceContainer {
    
    /// Shared instance for production use
    static let shared = ServiceContainer()
    
    /// The settings manager instance
    private(set) var settingsManager: any SettingsProviding
    
    /// The enforce mode service instance
    private(set) var enforceModeService: EnforceModeService
    
    /// The timer engine instance (created lazily)
    private var _timerEngine: TimerEngine?
    
    /// The fullscreen detection service
    private(set) var fullscreenService: FullscreenDetectionService?
    
    /// The idle monitoring service
    private(set) var idleService: IdleMonitoringService?
    
    /// The usage tracking service
    private(set) var usageTrackingService: UsageTrackingService?
    
    /// Whether this container is configured for testing
    let isTestEnvironment: Bool
    
    /// Creates a production container with real services
    private init() {
        self.isTestEnvironment = false
        self.settingsManager = SettingsManager.shared
        self.enforceModeService = EnforceModeService.shared
    }
    
    /// Creates a test container with injectable dependencies
    /// - Parameters:
    ///   - settingsManager: The settings manager to use
    ///   - enforceModeService: The enforce mode service to use
    init(
        settingsManager: any SettingsProviding,
        enforceModeService: EnforceModeService? = nil
    ) {
        self.isTestEnvironment = true
        self.settingsManager = settingsManager
        self.enforceModeService = enforceModeService ?? EnforceModeService.shared
    }
    
    /// Gets or creates the timer engine
    var timerEngine: TimerEngine {
        if let engine = _timerEngine {
            return engine
        }
        let engine = TimerEngine(
            settingsManager: settingsManager,
            enforceModeService: enforceModeService
        )
        _timerEngine = engine
        return engine
    }
    
    /// Sets a custom timer engine (useful for testing)
    func setTimerEngine(_ engine: TimerEngine) {
        _timerEngine = engine
    }
    
    /// Sets up smart mode services
    func setupSmartModeServices() {
        let settings = settingsManager.settings
        
        Task { @MainActor in
            fullscreenService = await FullscreenDetectionService.create()
            idleService = IdleMonitoringService(
                idleThresholdMinutes: settings.smartMode.idleThresholdMinutes
            )
            usageTrackingService = UsageTrackingService(
                resetThresholdMinutes: settings.smartMode.usageResetAfterMinutes
            )
            
            // Connect idle service to usage tracking
            if let idleService = idleService {
                usageTrackingService?.setupIdleMonitoring(idleService)
            }
            
            // Connect services to timer engine
            timerEngine.setupSmartMode(
                fullscreenService: fullscreenService,
                idleService: idleService
            )
        }
    }
    
    /// Resets the container for testing purposes
    func reset() {
        _timerEngine?.stop()
        _timerEngine = nil
        fullscreenService = nil
        idleService = nil
        usageTrackingService = nil
    }
    
    /// Creates a new container configured for testing with default mock settings
    static func forTesting(settings: AppSettings = .defaults) -> ServiceContainer {
        let mockSettings = MockSettingsManager(settings: settings)
        return ServiceContainer(settingsManager: mockSettings)
    }
}

/// A mock settings manager for use in ServiceContainer.forTesting()
/// This is a minimal implementation - use the full MockSettingsManager from tests for more features
@MainActor
@Observable
final class MockSettingsManager: SettingsProviding {
    var settings: AppSettings
    
    @ObservationIgnored
    private let _settingsSubject: CurrentValueSubject<AppSettings, Never>
    
    var settingsPublisher: AnyPublisher<AppSettings, Never> {
        _settingsSubject.eraseToAnyPublisher()
    }
    
    @ObservationIgnored
    private let timerConfigKeyPaths: [TimerType: WritableKeyPath<AppSettings, TimerConfiguration>] = [
        .lookAway: \.lookAwayTimer,
        .blink: \.blinkTimer,
        .posture: \.postureTimer,
    ]
    
    init(settings: AppSettings = .defaults) {
        self.settings = settings
        self._settingsSubject = CurrentValueSubject(settings)
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
        _settingsSubject.send(settings)
    }
    
    func allTimerConfigurations() -> [TimerType: TimerConfiguration] {
        var configs: [TimerType: TimerConfiguration] = [:]
        for (type, keyPath) in timerConfigKeyPaths {
            configs[type] = settings[keyPath: keyPath]
        }
        return configs
    }
    
    func save() { _settingsSubject.send(settings) }
    func saveImmediately() { _settingsSubject.send(settings) }
    func load() {}
    func resetToDefaults() { 
        settings = .defaults 
        _settingsSubject.send(settings)
    }
}
