//
//  WindowClasses.swift
//  Gaze
//
//  Custom NSWindow subclasses for different window behaviors.
//

import AppKit

/// Window that accepts keyboard and mouse focus (for overlay reminders)
class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Window that doesn't accept keyboard or mouse focus (for subtle reminders)
class NonKeyWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
