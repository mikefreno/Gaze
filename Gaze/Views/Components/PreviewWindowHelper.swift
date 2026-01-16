//
//  PreviewWindowHelper.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import AppKit
import SwiftUI

enum PreviewWindowHelper {
    static func showPreview<Content: View>(
        on screen: NSScreen,
        content: Content
    ) -> NSWindowController {
        let panel = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: content)
        panel.setFrame(screen.frame, display: true)

        let controller = NSWindowController(window: panel)
        controller.showWindow(nil)
        return controller
    }
}
