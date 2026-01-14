//
//  FullscreenDetectionService.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import AppKit
import Combine
import Foundation

@MainActor
class FullscreenDetectionService: ObservableObject {
    @Published private(set) var isFullscreenActive = false
    
    private var observers: [NSObjectProtocol] = []
    
    init() {
        setupObservers()
    }
    
    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        observers.forEach { notificationCenter.removeObserver($0) }
    }
    
    private func setupObservers() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        
        // Monitor when applications enter fullscreen
        let didEnterObserver = notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreenState()
            }
        }
        observers.append(didEnterObserver)
        
        // Monitor when active application changes
        let didActivateObserver = notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreenState()
            }
        }
        observers.append(didActivateObserver)
        
        // Initial check
        checkFullscreenState()
    }
    
    private func checkFullscreenState() {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            isFullscreenActive = false
            return
        }
        
        // Check if any window of the frontmost application is fullscreen
        let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
        let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        
        let frontmostPID = frontmostApp.processIdentifier
        
        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == frontmostPID,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let layer = window[kCGWindowLayer as String] as? Int else {
                continue
            }
            
            // Check if window is fullscreen by comparing bounds to screen size
            if let screen = NSScreen.main {
                let screenFrame = screen.frame
                let windowWidth = bounds["Width"] ?? 0
                let windowHeight = bounds["Height"] ?? 0
                
                // Window is considered fullscreen if it matches screen dimensions
                // and is at a normal window layer (0)
                if layer == 0 && 
                   abs(windowWidth - screenFrame.width) < 1 &&
                   abs(windowHeight - screenFrame.height) < 1 {
                    isFullscreenActive = true
                    return
                }
            }
        }
        
        isFullscreenActive = false
    }
    
    func forceUpdate() {
        checkFullscreenState()
    }
}
