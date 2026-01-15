//
//  ServiceContainer.swift
//  Gaze
//
//  Dependency injection container for managing service instances.
//

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
    ///   - settingsManager: The settings manager to use (defaults to MockSettingsManager in tests)
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
    
    /// Sets up smart mode services
    func setupSmartModeServices() {
        let settings = settingsManager.settings
        
        fullscreenService = FullscreenDetectionService()
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
    
    /// Resets the container for testing purposes
    func reset() {
        _timerEngine?.stop()
        _timerEngine = nil
        fullscreenService = nil
        idleService = nil
        usageTrackingService = nil
    }
    
    /// Creates a new container configured for testing
    static func forTesting(settings: AppSettings = .defaults) -> ServiceContainer {
        // We need to create this at runtime in tests using MockSettingsManager
        fatalError("Use init(settingsManager:) directly in tests")
    }
}
