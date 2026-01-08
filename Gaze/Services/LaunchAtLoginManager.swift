//
//  LaunchAtLoginManager.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Foundation
import ServiceManagement

class LaunchAtLoginManager {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        } else {
            // Fallback for macOS 12 and earlier
            return false
        }
    }
    
    static func enable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.register()
        } else {
            throw LaunchAtLoginError.unsupportedOS
        }
    }
    
    static func disable() throws {
        if #available(macOS 13.0, *) {
            try SMAppService.mainApp.unregister()
        } else {
            throw LaunchAtLoginError.unsupportedOS
        }
    }
    
    static func toggle() {
        do {
            if isEnabled {
                try disable()
            } else {
                try enable()
            }
        } catch {
            print("Failed to toggle launch at login: \(error)")
        }
    }
}

enum LaunchAtLoginError: Error {
    case unsupportedOS
    case registrationFailed
}
