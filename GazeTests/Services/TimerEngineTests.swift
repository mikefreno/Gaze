//
//  TimerEngineTests.swift
//  GazeTests
//
//  Unit tests for TimerEngine service.
//

import Combine
import XCTest

@testable import Gaze

@MainActor
final class TimerEngineTests: XCTestCase {

    var testEnv: TestEnvironment!
    var timerEngine: TimerEngine!
    var systemSleepManager: SystemSleepManager!
    var cancellables: Set<AnyCancellable>!

    override func setUp() async throws {
        testEnv = TestEnvironment(settings: .defaults)
        timerEngine = testEnv.container.timerEngine
        systemSleepManager = SystemSleepManager(
            timerEngine: timerEngine,
            settingsManager: testEnv.settingsManager
        )
        cancellables = []
    }

    override func tearDown() async throws {
        timerEngine?.stop()
        systemSleepManager?.stopObserving()
        cancellables = nil
        timerEngine = nil
        systemSleepManager = nil
        testEnv = nil
    }

    // MARK: - Initialization Tests

    func testTimerEngineInitialization() {
        XCTAssertNotNil(timerEngine)
        XCTAssertEqual(timerEngine.timerStates.count, 0)
        XCTAssertNil(timerEngine.activeReminder)
    }

    func testTimerEngineWithCustomTimeProvider() {
        let timeProvider = MockTimeProvider()
        let engine = TimerEngine(
            settingsManager: testEnv.settingsManager,
            enforceModeService: nil,
            timeProvider: timeProvider
        )

        XCTAssertNotNil(engine)
    }

    // MARK: - Start/Stop Tests

    func testStartTimers() {
        timerEngine.start()

        // Should create timer states for enabled timers
        XCTAssertGreaterThan(timerEngine.timerStates.count, 0)
    }

    func testStopTimers() {
        timerEngine.start()
        let initialCount = timerEngine.timerStates.count
        XCTAssertGreaterThan(initialCount, 0)

        timerEngine.stop()

        // Timers should be cleared
        XCTAssertEqual(timerEngine.timerStates.count, 0)
    }

    func testRestartTimers() {
        timerEngine.start()
        let firstCount = timerEngine.timerStates.count

        timerEngine.stop()
        XCTAssertEqual(timerEngine.timerStates.count, 0)

        timerEngine.start()
        let secondCount = timerEngine.timerStates.count

        XCTAssertEqual(firstCount, secondCount)
    }

    // MARK: - Pause/Resume Tests

    func testPauseAllTimers() {
        timerEngine.start()
        timerEngine.pause()

        for (_, state) in timerEngine.timerStates {
            XCTAssertTrue(state.isPaused)
        }
    }

    func testResumeAllTimers() {
        timerEngine.start()
        timerEngine.pause()
        timerEngine.resume()

        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }

    func testPauseSpecificTimer() {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        timerEngine.pauseTimer(identifier: firstTimer)

        let state = timerEngine.timerStates[firstTimer]
        XCTAssertTrue(state?.isPaused ?? false)
    }

    func testResumeSpecificTimer() {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        timerEngine.pauseTimer(identifier: firstTimer)
        XCTAssertTrue(timerEngine.isTimerPaused(firstTimer))

        timerEngine.resumeTimer(identifier: firstTimer)
        XCTAssertFalse(timerEngine.isTimerPaused(firstTimer))
    }

    // MARK: - Skip Tests

    func testSkipNext() {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        timerEngine.skipNext(identifier: firstTimer)

        // Timer should be reset
        XCTAssertNotNil(timerEngine.timerStates[firstTimer])
    }

    // MARK: - Reminder Tests

    func testTriggerReminder() async throws {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        timerEngine.triggerReminder(for: firstTimer)

        try await Task.sleep(for: .milliseconds(50))

        XCTAssertNotNil(timerEngine.activeReminder)
    }

    func testDismissReminder() {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        timerEngine.triggerReminder(for: firstTimer)
        XCTAssertNotNil(timerEngine.activeReminder)

        timerEngine.dismissReminder()
        XCTAssertNil(timerEngine.activeReminder)
    }

    // MARK: - Time Remaining Tests

    func testGetTimeRemaining() {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        let remaining = timerEngine.getTimeRemaining(for: firstTimer)
        XCTAssertGreaterThan(remaining, 0)
    }

    func testGetFormattedTimeRemaining() {
        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        let formatted = timerEngine.getFormattedTimeRemaining(for: firstTimer)
        XCTAssertFalse(formatted.isEmpty)
        XCTAssertTrue(formatted.contains(":"))
    }

    // MARK: - Timer State Publisher Tests

    func testTimerStatesPublisher() async throws {
        let expectation = XCTestExpectation(description: "Timer states changed")

        timerEngine.$timerStates
            .dropFirst()
            .sink { states in
                if !states.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        timerEngine.start()

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testActiveReminderPublisher() async throws {
        let expectation = XCTestExpectation(description: "Active reminder changed")

        timerEngine.$activeReminder
            .dropFirst()
            .sink { reminder in
                if reminder != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        timerEngine.start()

        guard let firstTimer = timerEngine.timerStates.keys.first else {
            XCTFail("No timers available")
            return
        }

        timerEngine.triggerReminder(for: firstTimer)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    // MARK: - System Sleep/Wake Tests

    func testSystemSleepManagerHandlesSleep() {
        timerEngine.start()
        let statesBefore = timerEngine.timerStates.count

        systemSleepManager.handleSystemWillSleep()

        // States should still exist
        XCTAssertEqual(timerEngine.timerStates.count, statesBefore)
    }

    func testSystemSleepManagerHandlesWake() {
        timerEngine.start()
        systemSleepManager.handleSystemWillSleep()
        systemSleepManager.handleSystemDidWake()

        // Should handle wake event without crashing
        XCTAssertGreaterThan(timerEngine.timerStates.count, 0)
    }

    // MARK: - Disabled Timer Tests

    func testDisabledTimersNotInitialized() {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.enabled = false
        settings.blinkTimer.enabled = false
        settings.postureTimer.enabled = false

        let settingsManager = EnhancedMockSettingsManager(settings: settings)
        let engine = TimerEngine(settingsManager: settingsManager)

        engine.start()

        XCTAssertEqual(engine.timerStates.count, 0)
    }

    func testPartiallyEnabledTimers() {
        var settings = AppSettings.defaults
        settings.lookAwayTimer.enabled = true
        settings.blinkTimer.enabled = false
        settings.postureTimer.enabled = false

        let settingsManager = EnhancedMockSettingsManager(settings: settings)
        let engine = TimerEngine(settingsManager: settingsManager)

        engine.start()

        XCTAssertEqual(engine.timerStates.count, 1)
    }
}
