//
//  MenuBarGuideOverlayView.swift
//  Gaze
//
//  Created by Mike Freno on 1/17/26.
//

import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarGuideOverlayPresenter {
    static let shared = MenuBarGuideOverlayPresenter()

    private var window: NSWindow?
    private var displayLink: CVDisplayLink?
    private var lastWindowFrame: CGRect = .zero
    private var onboardingWindowObserver: NSObjectProtocol?

    func updateVisibility(isVisible: Bool) {
        if isVisible {
            MenuBarItemLocator.shared.probeLocation()
            show()
        } else {
            hide()
        }
    }

    func hide() {
        stopDisplayLink()
        window?.orderOut(nil)
        window?.close()
        window = nil
    }

    private func show() {
        if let window {
            window.orderFrontRegardless()
            startDisplayLink()
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

        let overlayView = MenuBarGuideOverlayView()
        overlayWindow.contentView = NSHostingView(rootView: overlayView)

        overlayWindow.orderFrontRegardless()
        window = overlayWindow

        startDisplayLink()
    }

    private func startDisplayLink() {
        guard displayLink == nil else { return }

        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let displayLink = link else { return }

        let Doc = Unmanaged.passUnretained(self).toOpaque()

        CVDisplayLinkSetOutputCallback(
            displayLink,
            { _, _, _, _, _, userInfo -> CVReturn in
                guard let userInfo = userInfo else { return kCVReturnSuccess }
                let presenter = Unmanaged<MenuBarGuideOverlayPresenter>.fromOpaque(userInfo)
                    .takeUnretainedValue()
                DispatchQueue.main.async {
                    presenter.checkAndRedraw()
                }
                return kCVReturnSuccess
            }, Doc)

        CVDisplayLinkStart(displayLink)
        self.displayLink = displayLink
    }

    private func stopDisplayLink() {
        guard let displayLink else { return }
        CVDisplayLinkStop(displayLink)
        self.displayLink = nil
    }

    private func checkAndRedraw() {
        guard
            let onboardingWindow = NSApp.windows.first(where: {
                $0.identifier == WindowIdentifiers.onboarding
            })
        else { return }

        let currentFrame = onboardingWindow.frame
        if currentFrame != lastWindowFrame {
            lastWindowFrame = currentFrame
            redraw()
        }
    }

    private func redraw() {
        guard let window else { return }
        let overlayView = MenuBarGuideOverlayView()
        window.contentView = NSHostingView(rootView: overlayView)
    }

    func setupOnboardingWindowObserver() {
        // Remove any existing observer to prevent duplicates
        if let observer = onboardingWindowObserver {
            NotificationCenter.default.removeObserver(observer)
        }

        // Add observer for when the onboarding window is closed
        onboardingWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let window = notification.object as? NSWindow,
                window.identifier == WindowIdentifiers.onboarding
            else {
                return
            }

            // Hide the overlay when onboarding window closes
            self?.hide()
        }
    }
}

struct MenuBarGuideOverlayView: View {
    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            if let locationResult = MenuBarItemLocator.shared.getLocation(),
                let screen = NSScreen.main
            {
                let target = targetPoint(from: locationResult.frame)
                let start = startPoint(screenSize: size, screenFrame: screen.frame)

                HandDrawnArrowShape(start: start, end: target)
                    .stroke(
                        Color.accentColor.opacity(0.85),
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
            }
        }
        .allowsHitTesting(false)
        .background(Color.clear)
    }

    private func targetPoint(from frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: 30)
    }

    private func startPoint(screenSize: CGSize, screenFrame: CGRect) -> CGPoint {
        // Calculate start point based on onboarding window position
        // Arrow starts from right side of title text area (approximately)
        if let onboardingWindow = NSApp.windows.first(where: {
            $0.identifier == WindowIdentifiers.onboarding
        }) {
            let windowFrame = onboardingWindow.frame
            let textRightX = windowFrame.midX + 40
            let textY = screenFrame.maxY - windowFrame.maxY + 255
            return CGPoint(x: textRightX, y: textY)
        }
        return CGPoint(x: screenSize.width * 0.5, y: screenSize.height * 0.45)
    }
}

struct HandDrawnArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Create a path that starts going DOWN, then curves back UP to the target
        // This creates a more playful, hand-drawn feel

        let dx = end.x - start.x

        // First control point: go DOWN and slightly toward target
        let ctrl1 = CGPoint(
            x: start.x + dx * 0.15,
            y: start.y + 40
        )

        let ctrl2 = CGPoint(
            x: start.x + dx * 0.6,
            y: start.y + 80
        )

        let wobble: CGFloat = 2.5
        let wobbledCtrl1 = CGPoint(x: ctrl1.x + wobble, y: ctrl1.y - wobble)
        let wobbledCtrl2 = CGPoint(x: ctrl2.x - wobble, y: ctrl2.y + wobble)

        path.move(to: start)
        path.addCurve(to: end, control1: wobbledCtrl1, control2: wobbledCtrl2)

        // Arrowhead - angled based on the final curve direction
        let arrowLength: CGFloat = 16
        let arrowAngle: CGFloat = .pi / 6

        // Calculate angle from last control point to end
        let angle = atan2(end.y - wobbledCtrl2.y, end.x - wobbledCtrl2.x)

        let left = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let right = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        // Draw arrowhead with slight wobble
        path.move(to: CGPoint(x: end.x + 1, y: end.y - 1))
        path.addLine(to: CGPoint(x: left.x - 1, y: left.y + 1))
        path.move(to: CGPoint(x: end.x - 1, y: end.y + 1))
        path.addLine(to: CGPoint(x: right.x + 1, y: right.y - 1))

        return path
    }
}

#Preview("Menu Bar Guide Overlay") {
    MenuBarGuideOverlayView()
        .frame(width: 1200, height: 800)
}
