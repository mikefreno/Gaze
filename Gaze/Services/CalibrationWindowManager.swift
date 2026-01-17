//
//  CalibrationWindowManager.swift
//  Gaze
//
//  Manages the fullscreen calibration overlay window.
//

import AppKit
import SwiftUI

@MainActor
final class CalibrationWindowManager {
    static let shared = CalibrationWindowManager()
    
    private var windowController: NSWindowController?
    
    private init() {}
    
    func showCalibrationOverlay() {
        guard let screen = NSScreen.main else { return }
        
        let window = KeyableWindow(
            contentRect: screen.frame,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.level = .screenSaver
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.acceptsMouseMovedEvents = true
        window.ignoresMouseEvents = false
        
        let overlayView = CalibrationOverlayView {
            self.dismissCalibrationOverlay()
        }
        window.contentView = NSHostingView(rootView: overlayView)
        
        windowController = NSWindowController(window: window)
        windowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        print("🎯 Calibration overlay window opened")
    }
    
    func dismissCalibrationOverlay() {
        windowController?.close()
        windowController = nil
        print("🎯 Calibration overlay window closed")
    }
}
