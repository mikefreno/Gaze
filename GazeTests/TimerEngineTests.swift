//
//  TimerEngineTests.swift
//  GazeTests
//
//  Created by Mike Freno on 1/7/26.
//

import XCTest
@testable import Gaze

@MainActor
final class TimerEngineTests: XCTestCase {
    
    var timerEngine: TimerEngine!
    var mockSettings: MockSettingsManager!
    
    override func setUp() async throws {
        try await super.setUp()
        mockSettings = MockSettingsManager()
        timerEngine = TimerEngine(settingsManager: mockSettings, enforceModeService: nil)
    }
    
    override func tearDown() async throws {
        timerEngine.stop()
        mockSettings = nil
        try await super.tearDown()
    }
    
    func testTimerInitialization() {
        // Enable all timers for this test (blink is disabled by default)
        mockSettings.enableTimer(.blink)
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 3)
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.lookAway)])
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.blink)])
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.posture)])
    }
    
    func testDisabledTimersNotInitialized() {
        // Blink is disabled by default, so we should only have 2 timers
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 2)
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.lookAway)])
        XCTAssertNil(timerEngine.timerStates[.builtIn(.blink)])
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.posture)])
    }
    
    func testTimerStateInitialValues() {
        timerEngine.start()
        
        let lookAwayState = timerEngine.timerStates[.builtIn(.lookAway)]!
        XCTAssertEqual(lookAwayState.identifier, .builtIn(.lookAway))
        XCTAssertEqual(lookAwayState.remainingSeconds, 20 * 60)
        XCTAssertFalse(lookAwayState.isPaused)
        XCTAssertTrue(lookAwayState.isActive)
    }
    
    func testPauseAllTimers() {
        mockSettings.enableTimer(.blink)
        timerEngine.start()
        timerEngine.pause()
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertTrue(state.isPaused)
        }
    }
    
    func testResumeAllTimers() {
        mockSettings.enableTimer(.blink)
        timerEngine.start()
        timerEngine.pause()
        timerEngine.resume()
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }
    
    func testSkipNext() {
        mockSettings.setTimerInterval(.lookAway, seconds: 60)
        timerEngine.start()
        
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 10
        
        timerEngine.skipNext(identifier: .builtIn(.lookAway))
        
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds, 60)
    }
    
    func testGetTimeRemaining() {
        timerEngine.start()
        
        let timeRemaining = timerEngine.getTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(timeRemaining, TimeInterval(20 * 60))
    }
    
    func testGetFormattedTimeRemaining() {
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 125
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(formatted, "2:05")
    }
    
    func testGetFormattedTimeRemainingWithHours() {
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 3665
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(formatted, "1:01:05")
    }
    
    func testStop() {
        timerEngine.start()
        XCTAssertFalse(timerEngine.timerStates.isEmpty)
        
        timerEngine.stop()
        XCTAssertTrue(timerEngine.timerStates.isEmpty)
    }
    
    func testDismissReminderResetsTimer() {
        mockSettings.enableTimer(.blink)
        mockSettings.setTimerInterval(.blink, seconds: 7 * 60)
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.blink)]?.remainingSeconds = 0
        timerEngine.activeReminder = .blinkTriggered
        
        timerEngine.dismissReminder()
        
        XCTAssertNil(timerEngine.activeReminder)
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.blink)]?.remainingSeconds, 7 * 60)
    }
    
    func testDismissLookAwayResumesTimer() {
        timerEngine.start()
        // Trigger reminder pauses only the lookAway timer
        timerEngine.triggerReminder(for: .builtIn(.lookAway))
        
        XCTAssertNotNil(timerEngine.activeReminder)
        XCTAssertTrue(timerEngine.isTimerPaused(.builtIn(.lookAway)))
        
        timerEngine.dismissReminder()
        
        // After dismiss, the lookAway timer should be resumed
        XCTAssertFalse(timerEngine.isTimerPaused(.builtIn(.lookAway)))
    }
    
    func testTriggerReminderForLookAway() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .builtIn(.lookAway))
        
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .lookAwayTriggered(let countdown) = timerEngine.activeReminder {
            XCTAssertEqual(countdown, mockSettings.settings.lookAwayCountdownSeconds)
        } else {
            XCTFail("Expected lookAwayTriggered reminder")
        }
        
        // Only the triggered timer should be paused
        XCTAssertTrue(timerEngine.isTimerPaused(.builtIn(.lookAway)))
    }
    
    func testTriggerReminderForBlink() {
        mockSettings.enableTimer(.blink)
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .builtIn(.blink))
        
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .blinkTriggered = timerEngine.activeReminder {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected blinkTriggered reminder")
        }
    }
    
    func testTriggerReminderForPosture() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .builtIn(.posture))
        
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .postureTriggered = timerEngine.activeReminder {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected postureTriggered reminder")
        }
    }
    
    func testGetTimeRemainingForNonExistentTimer() {
        let timeRemaining = timerEngine.getTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(timeRemaining, 0)
    }
    
    func testGetFormattedTimeRemainingZeroSeconds() {
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 0
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(formatted, "0:00")
    }
    
    func testGetFormattedTimeRemainingLessThanMinute() {
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 45
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(formatted, "0:45")
    }
    
    func testGetFormattedTimeRemainingExactHour() {
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 3600
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .builtIn(.lookAway))
        XCTAssertEqual(formatted, "1:00:00")
    }
    
    func testMultipleStartCallsPreserveTimerState() {
        // When start() is called multiple times while already running,
        // it should preserve existing timer state (not reset)
        timerEngine.start()
        timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds = 100
        
        timerEngine.start()
        
        // Timer state is preserved since interval hasn't changed
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.lookAway)]?.remainingSeconds, 100)
    }
    
    func testSkipNextPreservesPausedState() {
        timerEngine.start()
        timerEngine.pause()
        
        timerEngine.skipNext(identifier: .builtIn(.lookAway))
        
        XCTAssertTrue(timerEngine.timerStates[.builtIn(.lookAway)]?.isPaused ?? false)
    }
    
    func testSkipNextPreservesActiveState() {
        timerEngine.start()
        
        timerEngine.skipNext(identifier: .builtIn(.lookAway))
        
        XCTAssertTrue(timerEngine.timerStates[.builtIn(.lookAway)]?.isActive ?? false)
    }
    
    func testDismissReminderWithNoActiveReminder() {
        timerEngine.start()
        XCTAssertNil(timerEngine.activeReminder)
        
        timerEngine.dismissReminder()
        
        XCTAssertNil(timerEngine.activeReminder)
    }
    
    func testDismissBlinkReminderResumesTimer() {
        mockSettings.enableTimer(.blink)
        timerEngine.start()
        timerEngine.triggerReminder(for: .builtIn(.blink))
        
        timerEngine.dismissReminder()
        
        // The blink timer should be resumed after dismissal
        XCTAssertFalse(timerEngine.isTimerPaused(.builtIn(.blink)))
    }
    
    func testDismissPostureReminderResumesTimer() {
        timerEngine.start()
        timerEngine.triggerReminder(for: .builtIn(.posture))
        
        timerEngine.dismissReminder()
        
        // The posture timer should be resumed after dismissal
        XCTAssertFalse(timerEngine.isTimerPaused(.builtIn(.posture)))
    }
    
    func testAllTimersStartWhenEnabled() {
        mockSettings.enableTimer(.lookAway)
        mockSettings.enableTimer(.blink)
        mockSettings.enableTimer(.posture)
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 3)
        for builtInTimer in TimerType.allCases {
            XCTAssertNotNil(timerEngine.timerStates[.builtIn(builtInTimer)])
        }
    }
    
    func testAllTimersDisabled() {
        mockSettings.disableTimer(.lookAway)
        mockSettings.disableTimer(.blink)
        mockSettings.disableTimer(.posture)
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 0)
    }
    
    func testPartialTimersEnabled() {
        mockSettings.enableTimer(.lookAway)
        mockSettings.disableTimer(.blink)
        mockSettings.enableTimer(.posture)
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 2)
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.lookAway)])
        XCTAssertNil(timerEngine.timerStates[.builtIn(.blink)])
        XCTAssertNotNil(timerEngine.timerStates[.builtIn(.posture)])
    }
    
    func testMultipleReminderTypesCanTriggerSimultaneously() {
        // Setup: Create a user timer with overlay type (focus-stealing)
        let overlayTimer = UserTimer(
            title: "Water Break",
            type: .overlay,
            timeOnScreenSeconds: 10,
            intervalMinutes: 1,
            message: "Drink water"
        )
        mockSettings.addUserTimer(overlayTimer)
        
        timerEngine.start()
        
        // Trigger an overlay reminder (look away or user timer overlay)
        timerEngine.triggerReminder(for: .user(id: overlayTimer.id))
        
        // Verify overlay reminder is active
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .userTimerTriggered(let timer) = timerEngine.activeReminder {
            XCTAssertEqual(timer.id, overlayTimer.id)
            XCTAssertEqual(timer.type, .overlay)
        } else {
            XCTFail("Expected userTimerTriggered with overlay type")
        }
        
        // Verify the overlay timer is paused
        XCTAssertTrue(timerEngine.isTimerPaused(.user(id: overlayTimer.id)))
        
        // Now trigger a subtle reminder (blink) while overlay is still active
        timerEngine.triggerReminder(for: .builtIn(.blink))
        
        // The activeReminder should be replaced with the blink reminder
        // This is expected behavior - TimerEngine only tracks one activeReminder
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .blinkTriggered = timerEngine.activeReminder {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected blinkTriggered reminder")
        }
        
        // Both timers should be paused (the one that triggered their reminder)
        XCTAssertTrue(timerEngine.isTimerPaused(.user(id: overlayTimer.id)))
        XCTAssertTrue(timerEngine.isTimerPaused(.builtIn(.blink)))
    }
    
    func testOverlayReminderDoesNotBlockSubtleReminders() {
        // Setup overlay user timer
        let overlayTimer = UserTimer(
            title: "Stand Up",
            type: .overlay,
            timeOnScreenSeconds: 10,
            intervalMinutes: 1
        )
        mockSettings.addUserTimer(overlayTimer)
        mockSettings.enableTimer(.blink)
        mockSettings.setTimerInterval(.blink, seconds: 60)
        
        timerEngine.start()
        
        // Trigger overlay reminder first
        timerEngine.triggerReminder(for: .user(id: overlayTimer.id))
        XCTAssertNotNil(timerEngine.activeReminder)
        XCTAssertTrue(timerEngine.isTimerPaused(.user(id: overlayTimer.id)))
        
        // Trigger subtle reminder while overlay is active
        timerEngine.triggerReminder(for: .builtIn(.blink))
        
        // The blink reminder should now be active
        if case .blinkTriggered = timerEngine.activeReminder {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected blinkTriggered reminder")
        }
        
        // Both timers should be paused
        XCTAssertTrue(timerEngine.isTimerPaused(.user(id: overlayTimer.id)))
        XCTAssertTrue(timerEngine.isTimerPaused(.builtIn(.blink)))
        
        // Dismiss the blink reminder
        timerEngine.dismissReminder()
        
        // After dismissing blink, the reminder should be cleared
        XCTAssertNil(timerEngine.activeReminder)
        
        // Blink timer should be reset and resumed
        XCTAssertFalse(timerEngine.isTimerPaused(.builtIn(.blink)))
        XCTAssertEqual(timerEngine.timerStates[.builtIn(.blink)]?.remainingSeconds, 60)
        
        // The overlay timer should still be paused
        XCTAssertTrue(timerEngine.isTimerPaused(.user(id: overlayTimer.id)))
    }
    
    // MARK: - Tests using injectable time provider
    
    func testTimerEngineWithMockTimeProvider() {
        let mockTime = MockTimeProvider(startTime: Date())
        let engine = TimerEngine(
            settingsManager: mockSettings,
            enforceModeService: nil,
            timeProvider: mockTime
        )
        
        engine.start()
        XCTAssertNotNil(engine.timerStates[.builtIn(.lookAway)])
        
        engine.stop()
    }
    
    func testSystemSleepWakeWithMockTime() {
        let startDate = Date()
        let mockTime = MockTimeProvider(startTime: startDate)
        let engine = TimerEngine(
            settingsManager: mockSettings,
            enforceModeService: nil,
            timeProvider: mockTime
        )
        
        engine.start()
        let initialRemaining = engine.timerStates[.builtIn(.lookAway)]?.remainingSeconds ?? 0
        
        // Simulate sleep
        engine.handleSystemSleep()
        XCTAssertTrue(engine.isTimerPaused(.builtIn(.lookAway)))
        
        // Advance mock time by 5 minutes
        mockTime.advance(by: 300)
        
        // Simulate wake
        engine.handleSystemWake()
        
        // Timer should resume and have adjusted remaining time
        XCTAssertFalse(engine.isTimerPaused(.builtIn(.lookAway)))
        let newRemaining = engine.timerStates[.builtIn(.lookAway)]?.remainingSeconds ?? 0
        XCTAssertEqual(newRemaining, initialRemaining - 300)
        
        engine.stop()
    }
}
