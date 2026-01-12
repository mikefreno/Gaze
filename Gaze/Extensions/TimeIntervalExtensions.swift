//
//  TimeIntervalExtensions.swift
//  Gaze
//
//  Created by Mike Freno on 1/11/26.
//

import Foundation

extension TimeInterval {
    /// Formats time interval as timer duration string
    /// Examples: "5m 30s", "1h 23m", "45s"
    func formatAsTimerDuration() -> String {
        let seconds = Int(self)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%dh %dm", hours, remainingMinutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", remainingSeconds)
        }
    }
    
    /// Formats time interval with full precision (hours:minutes:seconds)
    /// Example: "1:23:45" or "5:30"
    func formatAsTimerDurationFull() -> String {
        let seconds = Int(self)
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%d:%02d:%02d", hours, remainingMinutes, remainingSeconds)
        } else {
            return String(format: "%d:%02d", minutes, remainingSeconds)
        }
    }
}

extension Int {
    /// Formats integer seconds as timer duration
    var asTimerDuration: String {
        TimeInterval(self).formatAsTimerDuration()
    }
    
    /// Formats integer seconds with full precision
    var asTimerDurationFull: String {
        TimeInterval(self).formatAsTimerDurationFull()
    }
}
