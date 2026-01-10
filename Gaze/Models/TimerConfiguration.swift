//
//  TimerConfiguration.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation

struct TimerConfiguration: Codable, Equatable, Hashable {
    var enabled: Bool
    var intervalSeconds: Int
    
    init(enabled: Bool = true, intervalSeconds: Int) {
        self.enabled = enabled
        self.intervalSeconds = intervalSeconds
    }
    
    var intervalMinutes: Int {
        get { intervalSeconds / 60 }
        set { intervalSeconds = newValue * 60 }
    }
    
    static func == (lhs: TimerConfiguration, rhs: TimerConfiguration) -> Bool {
        lhs.enabled == rhs.enabled && lhs.intervalSeconds == rhs.intervalSeconds
    }
}
