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
    var settingsManager: SettingsManager!
    
    override func setUp() async throws {
        try await super.setUp()
        settingsManager = SettingsManager.shared
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        settingsManager.load()
        timerEngine = TimerEngine(settingsManager: settingsManager)
    }
    
    override func tearDown() async throws {
        timerEngine.stop()
        UserDefaults.standard.removeObject(forKey: "gazeAppSettings")
        try await super.tearDown()
    }
    
    func testTimerInitialization() {
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 3)
        XCTAssertNotNil(timerEngine.timerStates[.lookAway])
        XCTAssertNotNil(timerEngine.timerStates[.blink])
        XCTAssertNotNil(timerEngine.timerStates[.posture])
    }
    
    func testDisabledTimersNotInitialized() {
        settingsManager.settings.blinkTimer.enabled = false
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 2)
        XCTAssertNotNil(timerEngine.timerStates[.lookAway])
        XCTAssertNil(timerEngine.timerStates[.blink])
        XCTAssertNotNil(timerEngine.timerStates[.posture])
    }
    
    func testTimerStateInitialValues() {
        timerEngine.start()
        
        let lookAwayState = timerEngine.timerStates[.lookAway]!
        XCTAssertEqual(lookAwayState.type, .lookAway)
        XCTAssertEqual(lookAwayState.remainingSeconds, 20 * 60)
        XCTAssertFalse(lookAwayState.isPaused)
        XCTAssertTrue(lookAwayState.isActive)
    }
    
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
    
    func testSkipNext() {
        settingsManager.settings.lookAwayTimer.intervalSeconds = 60
        timerEngine.start()
        
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 10
        
        timerEngine.skipNext(type: .lookAway)
        
        XCTAssertEqual(timerEngine.timerStates[.lookAway]?.remainingSeconds, 60)
    }
    
    func testGetTimeRemaining() {
        timerEngine.start()
        
        let timeRemaining = timerEngine.getTimeRemaining(for: .lookAway)
        XCTAssertEqual(timeRemaining, TimeInterval(20 * 60))
    }
    
    func testGetFormattedTimeRemaining() {
        timerEngine.start()
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 125
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .lookAway)
        XCTAssertEqual(formatted, "2:05")
    }
    
    func testGetFormattedTimeRemainingWithHours() {
        timerEngine.start()
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 3665
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .lookAway)
        XCTAssertEqual(formatted, "1:01:05")
    }
    
    func testStop() {
        timerEngine.start()
        XCTAssertFalse(timerEngine.timerStates.isEmpty)
        
        timerEngine.stop()
        XCTAssertTrue(timerEngine.timerStates.isEmpty)
    }
    
    func testDismissReminderResetsTimer() {
        timerEngine.start()
        timerEngine.timerStates[.blink]?.remainingSeconds = 0
        timerEngine.activeReminder = .blinkTriggered
        
        timerEngine.dismissReminder()
        
        XCTAssertNil(timerEngine.activeReminder)
        XCTAssertEqual(timerEngine.timerStates[.blink]?.remainingSeconds, 5 * 60)
    }
    
    func testDismissLookAwayResumesTimers() {
        timerEngine.start()
        timerEngine.activeReminder = .lookAwayTriggered(countdownSeconds: 20)
        timerEngine.pause()
        
        timerEngine.dismissReminder()
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }
    
    func testTriggerReminderForLookAway() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .lookAway)
        
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .lookAwayTriggered(let countdown) = timerEngine.activeReminder {
            XCTAssertEqual(countdown, settingsManager.settings.lookAwayCountdownSeconds)
        } else {
            XCTFail("Expected lookAwayTriggered reminder")
        }
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertTrue(state.isPaused)
        }
    }
    
    func testTriggerReminderForBlink() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .blink)
        
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .blinkTriggered = timerEngine.activeReminder {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected blinkTriggered reminder")
        }
    }
    
    func testTriggerReminderForPosture() {
        timerEngine.start()
        
        timerEngine.triggerReminder(for: .posture)
        
        XCTAssertNotNil(timerEngine.activeReminder)
        if case .postureTriggered = timerEngine.activeReminder {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected postureTriggered reminder")
        }
    }
    
    func testGetTimeRemainingForNonExistentTimer() {
        let timeRemaining = timerEngine.getTimeRemaining(for: .lookAway)
        XCTAssertEqual(timeRemaining, 0)
    }
    
    func testGetFormattedTimeRemainingZeroSeconds() {
        timerEngine.start()
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 0
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .lookAway)
        XCTAssertEqual(formatted, "0:00")
    }
    
    func testGetFormattedTimeRemainingLessThanMinute() {
        timerEngine.start()
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 45
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .lookAway)
        XCTAssertEqual(formatted, "0:45")
    }
    
    func testGetFormattedTimeRemainingExactHour() {
        timerEngine.start()
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 3600
        
        let formatted = timerEngine.getFormattedTimeRemaining(for: .lookAway)
        XCTAssertEqual(formatted, "1:00:00")
    }
    
    func testMultipleStartCallsResetTimers() {
        timerEngine.start()
        timerEngine.timerStates[.lookAway]?.remainingSeconds = 100
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates[.lookAway]?.remainingSeconds, 20 * 60)
    }
    
    func testSkipNextPreservesPausedState() {
        timerEngine.start()
        timerEngine.pause()
        
        timerEngine.skipNext(type: .lookAway)
        
        XCTAssertTrue(timerEngine.timerStates[.lookAway]?.isPaused ?? false)
    }
    
    func testSkipNextPreservesActiveState() {
        timerEngine.start()
        
        timerEngine.skipNext(type: .lookAway)
        
        XCTAssertTrue(timerEngine.timerStates[.lookAway]?.isActive ?? false)
    }
    
    func testDismissReminderWithNoActiveReminder() {
        timerEngine.start()
        XCTAssertNil(timerEngine.activeReminder)
        
        timerEngine.dismissReminder()
        
        XCTAssertNil(timerEngine.activeReminder)
    }
    
    func testDismissBlinkReminderDoesNotResumeTimers() {
        timerEngine.start()
        timerEngine.activeReminder = .blinkTriggered
        
        timerEngine.dismissReminder()
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }
    
    func testDismissPostureReminderDoesNotResumeTimers() {
        timerEngine.start()
        timerEngine.activeReminder = .postureTriggered
        
        timerEngine.dismissReminder()
        
        for (_, state) in timerEngine.timerStates {
            XCTAssertFalse(state.isPaused)
        }
    }
    
    func testAllTimersStartWhenEnabled() {
        settingsManager.settings.lookAwayTimer.enabled = true
        settingsManager.settings.blinkTimer.enabled = true
        settingsManager.settings.postureTimer.enabled = true
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 3)
        for timerType in TimerType.allCases {
            XCTAssertNotNil(timerEngine.timerStates[timerType])
        }
    }
    
    func testAllTimersDisabled() {
        settingsManager.settings.lookAwayTimer.enabled = false
        settingsManager.settings.blinkTimer.enabled = false
        settingsManager.settings.postureTimer.enabled = false
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 0)
    }
    
    func testPartialTimersEnabled() {
        settingsManager.settings.lookAwayTimer.enabled = true
        settingsManager.settings.blinkTimer.enabled = false
        settingsManager.settings.postureTimer.enabled = true
        
        timerEngine.start()
        
        XCTAssertEqual(timerEngine.timerStates.count, 2)
        XCTAssertNotNil(timerEngine.timerStates[.lookAway])
        XCTAssertNil(timerEngine.timerStates[.blink])
        XCTAssertNotNil(timerEngine.timerStates[.posture])
    }
}
