//
//  FullscreenDetectionService.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

struct FullscreenWindowDescriptor: Equatable {
    let ownerPID: pid_t
    let layer: Int
    let bounds: CGRect
}

@MainActor
protocol FullscreenEnvironmentProviding {
    func frontmostProcessIdentifier() -> pid_t?
    func windowDescriptors() -> [FullscreenWindowDescriptor]
    func screenFrames() -> [CGRect]
}

@MainActor
struct SystemFullscreenEnvironmentProvider: FullscreenEnvironmentProviding {
    func frontmostProcessIdentifier() -> pid_t? {
        NSWorkspace.shared.frontmostApplication?.processIdentifier
    }

    func windowDescriptors() -> [FullscreenWindowDescriptor] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { window in
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat] else {
                return nil
            }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            return FullscreenWindowDescriptor(ownerPID: ownerPID, layer: layer, bounds: bounds)
        }
    }

    func screenFrames() -> [CGRect] {
        NSScreen.screens.map(\.frame)
    }
}

@MainActor
class FullscreenDetectionService: ObservableObject {
    @Published private(set) var isFullscreenActive = false

    private var observers: [NSObjectProtocol] = []
    private var frontmostAppObserver: AnyCancellable?
    private let permissionManager: ScreenCapturePermissionManaging
    private let environmentProvider: FullscreenEnvironmentProviding

    init(
        permissionManager: ScreenCapturePermissionManaging? = nil,
        environmentProvider: FullscreenEnvironmentProviding? = nil
    ) {
        self.permissionManager = permissionManager ?? ScreenCapturePermissionManager.shared
        self.environmentProvider = environmentProvider ?? SystemFullscreenEnvironmentProvider()
        setupObservers()
    }

    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        observers.forEach { notificationCenter.removeObserver($0) }
        frontmostAppObserver?.cancel()
    }

    private func setupObservers() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        let spaceObserver = notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: workspace,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        }
        observers.append(spaceObserver)

        let transitionObserver = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        }
        observers.append(transitionObserver)

        let fullscreenObserver = notificationCenter.addObserver(
            forName: NSWindow.willEnterFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        }
        observers.append(fullscreenObserver)

        let exitFullscreenObserver = notificationCenter.addObserver(
            forName: NSWindow.willExitFullScreenNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkFullscreenState()
        }
        observers.append(exitFullscreenObserver)

        frontmostAppObserver = NotificationCenter.default.publisher(
            for: NSWorkspace.didActivateApplicationNotification,
            object: workspace
        )
        .sink { [weak self] _ in
            self?.checkFullscreenState()
        }

        checkFullscreenState()
    }

    private func canReadWindowInfo() -> Bool {
        guard permissionManager.authorizationStatus.isAuthorized else {
            setFullscreenState(false)
            return false
        }

        return true
    }

    private func checkFullscreenState() {
        guard canReadWindowInfo() else { return }

        guard let frontmostPID = environmentProvider.frontmostProcessIdentifier() else {
            setFullscreenState(false)
            return
        }

        let windows = environmentProvider.windowDescriptors()
        let screens = environmentProvider.screenFrames()

        for window in windows where window.ownerPID == frontmostPID && window.layer == 0 {
            if screens.contains(where: { FullscreenDetectionService.window(window.bounds, matches: $0) }) {
                setFullscreenState(true)
                return
            }
        }

        setFullscreenState(false)
    }

    private static func window(_ windowBounds: CGRect, matches screenFrame: CGRect, tolerance: CGFloat = 1) -> Bool {
        abs(windowBounds.width - screenFrame.width) < tolerance &&
            abs(windowBounds.height - screenFrame.height) < tolerance &&
            abs(windowBounds.origin.x - screenFrame.origin.x) < tolerance &&
            abs(windowBounds.origin.y - screenFrame.origin.y) < tolerance
    }

    fileprivate func setFullscreenState(_ isActive: Bool) {
        guard isFullscreenActive != isActive else { return }
        isFullscreenActive = isActive
        print("🖥️ Fullscreen state updated: \(isActive ? "ACTIVE" : "INACTIVE")")
    }

    func forceUpdate() {
        checkFullscreenState()
    }

    #if DEBUG
        func simulateFullscreenStateForTesting(_ isActive: Bool) {
            setFullscreenState(isActive)
        }
    #endif
}
