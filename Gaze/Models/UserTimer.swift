//
//  UserTimer.swift
//  Gaze
//
//  Created by Mike Freno on 1/9/26.
//

import Foundation
import SwiftUI

/// Represents a user-defined timer with customizable properties
struct UserTimer: Codable, Equatable, Identifiable, Hashable {
    let id: String
    var title: String
    var type: UserTimerType
    var timeOnScreenSeconds: Int
    var message: String?
    var colorHex: String
    var enabled: Bool

    init(
        id: String = UUID().uuidString,
        title: String? = nil,
        type: UserTimerType = .subtle,
        timeOnScreenSeconds: Int = 30,
        message: String? = nil,
        colorHex: String? = nil,
        enabled: Bool = true
    ) {
        self.id = id
        self.title = title ?? "User Reminder"
        self.type = type
        self.timeOnScreenSeconds = timeOnScreenSeconds
        self.message = message
        self.colorHex = colorHex ?? UserTimer.defaultColors[0]
        self.enabled = enabled
    }

    static func == (lhs: UserTimer, rhs: UserTimer) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.type == rhs.type
            && lhs.timeOnScreenSeconds == rhs.timeOnScreenSeconds && lhs.message == rhs.message
            && lhs.colorHex == rhs.colorHex && lhs.enabled == rhs.enabled
    }
    
    // Default color palette for user timers
    static let defaultColors = [
        "9B59B6", // Purple
        "3498DB", // Blue
        "E74C3C", // Red
        "2ECC71", // Green
        "F39C12", // Orange
        "1ABC9C", // Teal
        "E91E63", // Pink
        "FF5722"  // Deep Orange
    ]
    
    var color: Color {
        Color(hex: colorHex) ?? .purple
    }
    
    static func generateTitle(for index: Int) -> String {
        "User Reminder \(index + 1)"
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        
        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }
        
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            return nil
        }
        
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
    
    var hexString: String? {
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        return String(format: "%02lX%02lX%02lX",
                     lroundf(r * 255),
                     lroundf(g * 255),
                     lroundf(b * 255))
    }
}

/// Type of user timer - subtle or overlay
enum UserTimerType: String, Codable, CaseIterable, Identifiable {
    case subtle
    case overlay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .subtle:
            return "Subtle"
        case .overlay:
            return "Overlay"
        }
    }
}

