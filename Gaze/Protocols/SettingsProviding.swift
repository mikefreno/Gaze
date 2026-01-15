//
//  SettingsProviding.swift
//  Gaze
//
//  Protocol abstraction for SettingsManager to enable dependency injection and testing.
//

import Combine
import Foundation

/// Protocol that defines the interface for managing application settings.
/// This abstraction allows for dependency injection and easy mocking in tests.
@MainActor
protocol SettingsProviding: AnyObject, ObservableObject {
    /// The current application settings
    var settings: AppSettings { get set }
    
    /// Publisher for observing settings changes
    var settingsPublisher: Published<AppSettings>.Publisher { get }
    
    /// Retrieves the timer configuration for a specific timer type
    func timerConfiguration(for type: TimerType) -> TimerConfiguration
    
    /// Updates the timer configuration for a specific timer type
    func updateTimerConfiguration(for type: TimerType, configuration: TimerConfiguration)
    
    /// Returns all timer configurations
    func allTimerConfigurations() -> [TimerType: TimerConfiguration]
    
    /// Saves settings to persistent storage
    func save()
    
    /// Forces immediate save
    func saveImmediately()
    
    /// Loads settings from persistent storage
    func load()
    
    /// Resets settings to default values
    func resetToDefaults()
}

/// Extension to provide the publisher for SettingsManager
extension SettingsManager: SettingsProviding {
    var settingsPublisher: Published<AppSettings>.Publisher {
        $settings
    }
}
