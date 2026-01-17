//
//  MenuBarGuideOverlayView.swift
//  Gaze
//
//  Created by Mike Freno on 1/17/26.
//

import AppKit
import SwiftUI

@MainActor
final class MenuBarGuideOverlayPresenter {
    static let shared = MenuBarGuideOverlayPresenter()

    private var window: NSWindow?

    func updateVisibility(isVisible: Bool) {
        if isVisible {
            // Probe location before showing
            MenuBarItemLocator.shared.probeLocation()
            show()
        } else {
            hide()
        }
    }

    func hide() {
        window?.orderOut(nil)
        window?.close()
        window = nil
    }

    private func show() {
        if let window {
            window.orderFrontRegardless()
            return
        }

        guard let screen = NSScreen.main else { return }

        let overlayWindow = NSPanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        overlayWindow.backgroundColor = .clear
        overlayWindow.isOpaque = false
        overlayWindow.hasShadow = false
        overlayWindow.level = .statusBar
        overlayWindow.ignoresMouseEvents = true
        overlayWindow.isReleasedWhenClosed = false
        overlayWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        overlayWindow.contentView = NSHostingView(rootView: MenuBarGuideOverlayView())

        overlayWindow.orderFrontRegardless()
        window = overlayWindow
    }
}

struct MenuBarGuideOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            if let locationResult = MenuBarItemLocator.shared.getLocation(),
                let screen = NSScreen.main
            {
                let target = convertToViewCoordinates(
                    frame: locationResult.frame,
                    screenHeight: screen.frame.height
                )

                // Adjust control and start points based on target position
                let control = CGPoint(
                    x: target.x * 0.9 + size.width * 0.1,
                    y: size.height * 0.15
                )
                let start = CGPoint(
                    x: size.width * 0.5,
                    y: size.height * 0.45
                )

                CurvedArrowShape(start: start, end: target, control: control)
                    .stroke(
                        Color.accentColor.opacity(0.9),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
            }
        }
        .allowsHitTesting(false)
        .background(Color.clear)
    }

    private func convertToViewCoordinates(frame: CGRect, screenHeight: CGFloat) -> CGPoint {
        // We want to point to the center of the menu bar icon
        // x: use the center of the detected frame
        // y: fixed at ~20 from top (menu bar is at top of screen in view coordinates)
        let centerX = frame.midX
        let targetY: CGFloat = 30  // Fixed y near top of screen
        return CGPoint(x: centerX, y: targetY)
    }
}

struct CurvedArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint
    let control: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: start)
        path.addQuadCurve(to: end, control: control)

        // Arrowhead
        let arrowLength: CGFloat = 18
        let arrowAngle: CGFloat = .pi / 7
        let angle = atan2(end.y - control.y, end.x - control.x)

        let left = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let right = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        path.move(to: end)
        path.addLine(to: left)
        path.move(to: end)
        path.addLine(to: right)

        return path
    }
}

#Preview("Menu Bar Guide Overlay") {
    MenuBarGuideOverlayView()
        .frame(width: 1200, height: 800)
}
