//
//  MenuBarItemLocator.swift
//  Gaze
//
//  Created by Mike Freno on 1/17/26.
//

import AppKit
import Foundation

struct MenuBarLocationResult {
    let frame: CGRect
}

final class MenuBarItemLocator {
    static let shared = MenuBarItemLocator()

    private var cachedLocation: MenuBarLocationResult?

    private init() {}

    func probeLocation() {
        // Strategy 1: NSApp.windows at status bar level (most reliable)
        if let result = findViaAppWindows() {
            print("✅ Strategy 1 (NSApp.windows level 25): \(result.frame)")
            cachedLocation = result
            return
        }
        
        // Strategy 2: CGWindowList
        if let result = findViaCGWindowList() {
            print("✅ Strategy 2 (CGWindowList): \(result.frame)")
            cachedLocation = result
            return
        }
        
        // Strategy 3: Calculate based on screen geometry
        if let result = calculateFromScreenGeometry() {
            print("✅ Strategy 3 (Screen geometry fallback): \(result.frame)")
            cachedLocation = result
            return
        }
        
        print("❌ All strategies failed")
    }

    func getLocation() -> MenuBarLocationResult? {
        if cachedLocation == nil {
            probeLocation()
        }
        return cachedLocation
    }

    /// Strategy 1: Find windows at status bar level (25) in NSApp.windows
    private func findViaAppWindows() -> MenuBarLocationResult? {
        guard let screen = NSScreen.main else { return nil }

        let menuBarHeight = NSStatusBar.system.thickness
        let screenFrame = screen.frame

        for window in NSApp.windows {
            let frame = window.frame
            let level = window.level.rawValue

            // Status bar level is 25
            let isStatusBarLevel = level == 25
            
            // Status item windows have small dimensions
            let hasSmallHeight = frame.height > 0 && frame.height <= 50
            let hasSmallWidth = frame.width > 0 && frame.width < 100

            if isStatusBarLevel && hasSmallHeight && hasSmallWidth {
                // We found it! Use the x position, but set y to top of screen
                let targetFrame = CGRect(
                    x: frame.minX,
                    y: screenFrame.maxY - menuBarHeight,
                    width: frame.width,
                    height: menuBarHeight
                )
                return MenuBarLocationResult(frame: targetFrame)
            }
        }

        return nil
    }

    /// Strategy 2: Use CGWindowListCopyWindowInfo
    private func findViaCGWindowList() -> MenuBarLocationResult? {
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let myPID = ProcessInfo.processInfo.processIdentifier
        guard let screen = NSScreen.main else { return nil }
        
        let menuBarHeight = NSStatusBar.system.thickness
        let screenHeight = screen.frame.height

        for info in windowList {
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == myPID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"],
                  let y = boundsDict["Y"],
                  let width = boundsDict["Width"],
                  let height = boundsDict["Height"]
            else { continue }

            // CGWindowList uses top-left origin (y=0 at top)
            let isAtTop = y < menuBarHeight + 10
            let hasSmallHeight = height > 0 && height <= 50
            let hasSmallWidth = width > 0 && width < 100

            if isAtTop && hasSmallHeight && hasSmallWidth {
                let frame = CGRect(
                    x: x,
                    y: screenHeight - menuBarHeight,
                    width: width,
                    height: menuBarHeight
                )
                return MenuBarLocationResult(frame: frame)
            }
        }

        return nil
    }

    /// Strategy 3: Fallback calculation based on screen geometry
    private func calculateFromScreenGeometry() -> MenuBarLocationResult? {
        guard let screen = NSScreen.main else { return nil }

        let menuBarHeight = NSStatusBar.system.thickness
        let screenFrame = screen.frame
        
        // Estimate: status items typically around 2/3 from left
        let estimatedX = screenFrame.width * 0.667
        
        let frame = CGRect(
            x: estimatedX,
            y: screenFrame.maxY - menuBarHeight,
            width: 24,
            height: menuBarHeight
        )

        return MenuBarLocationResult(frame: frame)
    }

    func refreshLocation() {
        cachedLocation = nil
        probeLocation()
    }
}
