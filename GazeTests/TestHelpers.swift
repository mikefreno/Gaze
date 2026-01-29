//
//  TestHelpers.swift
//  GazeTests
//
//  Test helpers and utilities for unit testing.
//

// MARK: - Import Statement for Combine
import Combine
import Foundation
import XCTest

@testable import Gaze

// MARK: - Enhanced MockSettingsManager

/// Enhanced mock settings manager with full control over state
@MainActor
@Observable
final class EnhancedMockSettingsManager: SettingsProviding {
    var settings: AppSettings

    @ObservationIgnored
    private let _settingsSubject: CurrentValueSubject<AppSettings, Never>

    var settingsPublisher: AnyPublisher<AppSettings, Never> {
        _settingsSubject.eraseToAnyPublisher()
    }

    @ObservationIgnored
    private let intervalKeyPaths: [TimerType: WritableKeyPath<AppSettings, Int>] =
        [
            .lookAway: \.lookAwayIntervalMinutes,
            .blink: \.blinkIntervalMinutes,
            .posture: \.postureIntervalMinutes,
        ]

    @ObservationIgnored
    private let enabledKeyPaths: [TimerType: WritableKeyPath<AppSettings, Bool>] =
        [
            .lookAway: \.lookAwayEnabled,
            .blink: \.blinkEnabled,
            .posture: \.postureEnabled,
        ]

    // Track method calls for verification
    @ObservationIgnored
    private(set) var saveCallCount = 0
    @ObservationIgnored
    private(set) var saveImmediatelyCallCount = 0
    @ObservationIgnored
    private(set) var loadCallCount = 0
    @ObservationIgnored
    private(set) var resetToDefaultsCallCount = 0

    init(settings: AppSettings = .defaults) {
        self.settings = settings
        self._settingsSubject = CurrentValueSubject(settings)
    }

    func timerIntervalMinutes(for type: TimerType) -> Int {
        guard let keyPath = intervalKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        return settings[keyPath: keyPath]
    }

    func isTimerEnabled(for type: TimerType) -> Bool {
        guard let keyPath = enabledKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        return settings[keyPath: keyPath]
    }

    func updateTimerInterval(for type: TimerType, minutes: Int) {
        guard let keyPath = intervalKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        settings[keyPath: keyPath] = minutes
        _settingsSubject.send(settings)
    }

    func updateTimerEnabled(for type: TimerType, enabled: Bool) {
        guard let keyPath = enabledKeyPaths[type] else {
            preconditionFailure("Unknown timer type: \(type)")
        }
        settings[keyPath: keyPath] = enabled
        _settingsSubject.send(settings)
    }

    func allTimerSettings() -> [TimerType: (enabled: Bool, intervalMinutes: Int)] {
        var settingsMap: [TimerType: (enabled: Bool, intervalMinutes: Int)] = [:]
        for (type, enabledKey) in enabledKeyPaths {
            settingsMap[type] = (enabled: settings[keyPath: enabledKey], intervalMinutes: settings[keyPath: intervalKeyPaths[type]!])
        }
        return settingsMap
    }

    func save() {
        saveCallCount += 1
        _settingsSubject.send(settings)
    }

    func saveImmediately() {
        saveImmediatelyCallCount += 1
        _settingsSubject.send(settings)
    }

    func load() {
        loadCallCount += 1
    }

    func resetToDefaults() {
        resetToDefaultsCallCount += 1
        settings = .defaults
        _settingsSubject.send(settings)
    }

    // Test helpers
    func reset() {
        saveCallCount = 0
        saveImmediatelyCallCount = 0
        loadCallCount = 0
        resetToDefaultsCallCount = 0
        settings = .defaults
        _settingsSubject.send(settings)
    }
}

// MARK: - Mock Smart Mode Services

@MainActor
final class MockFullscreenDetectionService: ObservableObject, FullscreenDetectionProviding {
    @Published var isFullscreenActive: Bool = false

    var isFullscreenActivePublisher: Published<Bool>.Publisher {
        $isFullscreenActive
    }

    private(set) var forceUpdateCallCount = 0

    func forceUpdate() {
        forceUpdateCallCount += 1
    }

    func simulateFullscreen(_ active: Bool) {
        isFullscreenActive = active
    }
}

@MainActor
final class MockIdleMonitoringService: ObservableObject, IdleMonitoringProviding {
    @Published var isIdle: Bool = false

    var isIdlePublisher: Published<Bool>.Publisher {
        $isIdle
    }

    private(set) var thresholdMinutes: Int = 5
    private(set) var forceUpdateCallCount = 0

    func updateThreshold(minutes: Int) {
        thresholdMinutes = minutes
    }

    func forceUpdate() {
        forceUpdateCallCount += 1
    }

    func simulateIdle(_ idle: Bool) {
        isIdle = idle
    }
}

// MARK: - Test Fixtures

extension AppSettings {
    /// Settings with all timers disabled
    static var allTimersDisabled: AppSettings {
        var settings = AppSettings.defaults
        settings.lookAwayEnabled = false
        settings.blinkEnabled = false
        settings.postureEnabled = false
        return settings
    }

    /// Settings with only lookAway timer enabled
    static var onlyLookAwayEnabled: AppSettings {
        var settings = AppSettings.defaults
        settings.lookAwayEnabled = true
        settings.blinkEnabled = false
        settings.postureEnabled = false
        return settings
    }

    /// Settings with short intervals for testing
    static var shortIntervals: AppSettings {
        var settings = AppSettings.defaults
        settings.lookAwayIntervalMinutes = 5
        settings.blinkIntervalMinutes = 3
        settings.postureIntervalMinutes = 7
        return settings
    }

    /// Settings with onboarding completed
    static var onboardingCompleted: AppSettings {
        var settings = AppSettings.defaults
        settings.hasCompletedOnboarding = true
        return settings
    }

    /// Settings with smart mode fully enabled
    static var smartModeEnabled: AppSettings {
        var settings = AppSettings.defaults
        settings.smartMode.autoPauseOnFullscreen = true
        settings.smartMode.autoPauseOnIdle = true
        settings.smartMode.idleThresholdMinutes = 5
        return settings
    }
}

// MARK: - Test Utilities

/// Creates a service container configured for testing
@MainActor
func createTestContainer(
    settings: AppSettings = .defaults
) -> TestServiceContainer {
    return TestServiceContainer(settings: settings)
}

/// Creates a complete test environment with all mocks
@MainActor
struct TestEnvironment {
    let container: TestServiceContainer
    let windowManager: MockWindowManager
    let settingsManager: EnhancedMockSettingsManager
    let timeProvider: MockTimeProvider

    init(settings: AppSettings = .defaults) {
        self.settingsManager = EnhancedMockSettingsManager(settings: settings)
        self.container = TestServiceContainer(settingsManager: settingsManager)
        self.windowManager = MockWindowManager()
        self.timeProvider = MockTimeProvider()
    }

    /// Creates an AppDelegate with all test dependencies
    func createAppDelegate() -> AppDelegate {
        return AppDelegate(serviceContainer: serviceContainer, windowManager: windowManager)
    }

    /// Resets all mock state
    func reset() {
        windowManager.reset()
        settingsManager.reset()
    }

    private var serviceContainer: ServiceContainer {
        ServiceContainer(
            settingsManager: settingsManager,
            enforceModeService: EnforceModeService.shared
        )
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Waits for a condition to be true with timeout
    @MainActor
    func waitFor(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 1.0,
        message: String = "Condition not met"
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail(message)
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
    }

    /// Waits for a published value to change
    @MainActor
    func waitForPublisher<T: Equatable>(
        _ publisher: Published<T>.Publisher,
        toEqual expectedValue: T,
        timeout: TimeInterval = 1.0
    ) async throws {
        let expectation = XCTestExpectation(description: "Publisher value changed")
        var cancellable: AnyCancellable?

        cancellable = publisher.sink { value in
            if value == expectedValue {
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: timeout)
        cancellable?.cancel()
    }
}
