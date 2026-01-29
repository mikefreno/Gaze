//
//  TimerEngineTestabilityTests.swift
//  GazeTests
//
//  Tests demonstrating TimerEngine testability with dependency injection.
//

import Combine
import XCTest

@testable import Gaze

@MainActor
final class TimerEngineTestabilityTests: XCTestCase {

    var testEnv: TestEnvironment!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        testEnv = TestEnvironment(settings: .shortIntervals)
        cancellables = []
    }

    override func tearDown() async throws {
        cancellables = nil
        testEnv = nil
    }

    func testTimerEngineCreationWithMocks() {
        let timeProvider = MockTimeProvider()
        let timerEngine = TimerEngine(
            settingsManager: testEnv.settingsManager,
            enforceModeService: nil,
            timeProvider: timeProvider
        )

        XCTAssertNotNil(timerEngine)
        XCTAssertEqual(timerEngine.timerStates.count, 0)
    }

    func testTimerEngineUsesInjectedSettings() {
        var settings = AppSettings.defaults
        settings.lookAwayEnabled = true
        settings.blinkEnabled = false
        settings.postureEnabled = false

        testEnv.settingsManager.settings = settings
        let timerEngine = testEnv.container.timerEngine

        timerEngine.start()

        // Only lookAway should be active
        let lookAwayTimer = timerEngine.timerStates.first { $0.key == .builtIn(.lookAway) }
        let blinkTimer = timerEngine.timerStates.first { $0.key == .builtIn(.blink) }

        XCTAssertNotNil(lookAwayTimer)
        XCTAssertNil(blinkTimer)
    }

    func testTimerEngineWithMockTimeProvider() {
        let timeProvider = MockTimeProvider(startTime: Date())
        let timerEngine = TimerEngine(
            settingsManager: testEnv.settingsManager,
            enforceModeService: nil,
            timeProvider: timeProvider
        )

        // Start timers
        timerEngine.start()

        // Advance time
        timeProvider.advance(by: 10)

        // Timer engine should use the mocked time
        XCTAssertNotNil(timerEngine.timerStates)
    }

    func testPauseAndResumeWithMocks() {
        let timerEngine = testEnv.container.timerEngine
        timerEngine.start()

        timerEngine.pause()

        // Verify all timers are paused
        for (_, state) in timerEngine.timerStates {
            XCTAssertTrue(state.isPaused)
        }

        timerEngine.resume()

        // Verify all timers are resumed
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }

    func testReminderEventPublishing() async throws {
        let timerEngine = testEnv.container.timerEngine

        var receivedReminder: ReminderEvent?
        timerEngine.$activeReminder
            .sink { reminder in
                receivedReminder = reminder
            }
            .store(in: &cancellables)

        let timerId = TimerIdentifier.builtIn(.lookAway)
        timerEngine.triggerReminder(for: timerId)

        try await Task.sleep(for: .milliseconds(10))

        XCTAssertNotNil(receivedReminder)
    }
}
