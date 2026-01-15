//
//  SmartModeProviding.swift
//  Gaze
//
//  Protocols for Smart Mode services (Fullscreen Detection, Idle Monitoring).
//

import Combine
import Foundation

/// Protocol for fullscreen detection functionality
@MainActor
protocol FullscreenDetectionProviding: AnyObject, ObservableObject {
    /// Whether a fullscreen app is currently active
    var isFullscreenActive: Bool { get }
    
    /// Publisher for fullscreen state changes
    var isFullscreenActivePublisher: Published<Bool>.Publisher { get }
    
    /// Forces an immediate state update
    func forceUpdate()
}

/// Protocol for idle monitoring functionality
@MainActor
protocol IdleMonitoringProviding: AnyObject, ObservableObject {
    /// Whether the user is currently idle
    var isIdle: Bool { get }
    
    /// Publisher for idle state changes
    var isIdlePublisher: Published<Bool>.Publisher { get }
    
    /// Updates the idle threshold
    func updateThreshold(minutes: Int)
    
    /// Forces an immediate state update
    func forceUpdate()
}

// MARK: - Extensions for conformance

extension FullscreenDetectionService: FullscreenDetectionProviding {
    var isFullscreenActivePublisher: Published<Bool>.Publisher {
        $isFullscreenActive
    }
}

extension IdleMonitoringService: IdleMonitoringProviding {
    var isIdlePublisher: Published<Bool>.Publisher {
        $isIdle
    }
}
