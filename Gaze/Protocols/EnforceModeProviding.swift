//
//  EnforceModeProviding.swift
//  Gaze
//
//  Protocol abstraction for EnforceModeService to enable dependency injection and testing.
//

import Combine
import Foundation

/// Protocol that defines the interface for enforce mode functionality.
protocol EnforceModeProviding: AnyObject, ObservableObject {
    /// Whether enforce mode is currently enabled
    var isEnforceModeEnabled: Bool { get }
    
    /// Whether the camera is currently active
    var isCameraActive: Bool { get }
    
    /// Whether the user has complied with the break
    var userCompliedWithBreak: Bool { get }
    
    /// Whether we're in test mode
    var isTestMode: Bool { get }
    
    /// Enables enforce mode (may request camera permission)
    func enableEnforceMode() async
    
    /// Disables enforce mode
    func disableEnforceMode()
    
    /// Sets the timer engine reference
    func setTimerEngine(_ engine: TimerEngine)
    
    /// Checks if a break should be enforced for the given timer
    func shouldEnforceBreak(for timerIdentifier: TimerIdentifier) -> Bool
    
    /// Starts the camera for lookaway timer
    func startCameraForLookawayTimer(secondsRemaining: Int) async
    
    /// Stops the camera
    func stopCamera()
    
    /// Checks if user is complying with the break
    func checkUserCompliance()
    
    /// Handles reminder dismissal
    func handleReminderDismissed()
    
    /// Starts test mode
    func startTestMode() async
    
    /// Stops test mode
    func stopTestMode()
}

extension EnforceModeService: EnforceModeProviding {}
