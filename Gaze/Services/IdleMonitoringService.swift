//
//  IdleMonitoringService.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import AppKit
import Combine
import Foundation

@MainActor
class IdleMonitoringService: ObservableObject {
    @Published private(set) var isIdle = false
    @Published private(set) var idleTimeSeconds: TimeInterval = 0
    
    private var timer: Timer?
    private var idleThresholdSeconds: TimeInterval
    
    init(idleThresholdMinutes: Int = 5) {
        self.idleThresholdSeconds = TimeInterval(idleThresholdMinutes * 60)
        startMonitoring()
    }
    
    deinit {
        timer?.invalidate()
    }
    
    func updateThreshold(minutes: Int) {
        idleThresholdSeconds = TimeInterval(minutes * 60)
        checkIdleState()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.checkIdleState()
            }
        }
    }
    
    private func checkIdleState() {
        idleTimeSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )
        
        // Also check keyboard events and use the minimum
        let keyboardIdleTime = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )
        
        idleTimeSeconds = min(idleTimeSeconds, keyboardIdleTime)
        
        let wasIdle = isIdle
        isIdle = idleTimeSeconds >= idleThresholdSeconds
        
        if wasIdle != isIdle {
            print("🔄 Idle state changed: \(isIdle ? "IDLE" : "ACTIVE") (idle: \(Int(idleTimeSeconds))s, threshold: \(Int(idleThresholdSeconds))s)")
        }
    }
    
    func forceUpdate() {
        checkIdleState()
    }
}
