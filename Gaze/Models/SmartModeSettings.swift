//
//  SmartModeSettings.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import Foundation

struct SmartModeSettings: Codable, Equatable, Hashable, Sendable {
    var autoPauseOnFullscreen: Bool
    var autoPauseOnIdle: Bool
    var trackUsage: Bool
    var idleThresholdMinutes: Int
    var usageResetAfterMinutes: Int
    
    init(
        autoPauseOnFullscreen: Bool = false,
        autoPauseOnIdle: Bool = false,
        trackUsage: Bool = false,
        idleThresholdMinutes: Int = 5,
        usageResetAfterMinutes: Int = 60
    ) {
        self.autoPauseOnFullscreen = autoPauseOnFullscreen
        self.autoPauseOnIdle = autoPauseOnIdle
        self.trackUsage = trackUsage
        self.idleThresholdMinutes = idleThresholdMinutes
        self.usageResetAfterMinutes = usageResetAfterMinutes
    }
    
    static var defaults: SmartModeSettings {
        SmartModeSettings(
            autoPauseOnFullscreen: false,
            autoPauseOnIdle: false,
            trackUsage: false,
            idleThresholdMinutes: 5,
            usageResetAfterMinutes: 60
        )
    }
}
