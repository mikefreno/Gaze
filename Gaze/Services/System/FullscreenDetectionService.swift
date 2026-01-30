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

public struct FullscreenWindowDescriptor: Equatable {
    public let ownerPID: pid_t
    public let layer: Int
    public let bounds: CGRect

    public init(ownerPID: pid_t, layer: Int, bounds: CGRect) {
        self.ownerPID = ownerPID
        self.layer = layer
        self.bounds = bounds
    }
}

protocol FullscreenEnvironmentProviding {
    func frontmostProcessIdentifier() -> pid_t?
    func windowDescriptors() -> [FullscreenWindowDescriptor]
    func screenFrames() -> [CGRect]
}

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

    public func screenFrames() -> [CGRect] {
        NSScreen.screens.map(\.frame)
    }
}

@MainActor
final class FullscreenDetectionService: ObservableObject {
    @Published private(set) var isFullscreenActive = false

    private var observers: [NSObjectProtocol] = []
    private var frontmostAppObserver: AnyCancellable?
    private let permissionManager: ScreenCapturePermissionManaging
    private let environmentProvider: FullscreenEnvironmentProviding
    private let windowMatcher = FullscreenWindowMatcher()

    init(
        permissionManager: ScreenCapturePermissionManaging,
        environmentProvider: FullscreenEnvironmentProviding
    ) {
        self.permissionManager = permissionManager
        self.environmentProvider = environmentProvider
        setupObservers()
    }
    
    /// Convenience initializer using default services
    convenience init() {
        self.init(
            permissionManager: ScreenCapturePermissionManager.shared,
            environmentProvider: SystemFullscreenEnvironmentProvider()
        )
    }
    
    // Factory method to safely create instances from non-main actor contexts
    static func create(
        permissionManager: ScreenCapturePermissionManaging? = nil,
        environmentProvider: FullscreenEnvironmentProviding? = nil
    ) async -> FullscreenDetectionService {
        await MainActor.run {
            return FullscreenDetectionService(
                permissionManager: permissionManager ?? ScreenCapturePermissionManager.shared,
                environmentProvider: environmentProvider ?? SystemFullscreenEnvironmentProvider()
            )
        }
    }

    deinit {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        observers.forEach { notificationCenter.removeObserver($0) }
        frontmostAppObserver?.cancel()
    }

    private func setupObservers() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter

        let stateChangeHandler: (Notification) -> Void = { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreenState()
            }
        }

        let notifications: [(NSNotification.Name, Any?)] = [
            (NSWorkspace.activeSpaceDidChangeNotification, workspace),
            (NSApplication.didChangeScreenParametersNotification, nil),
            (NSWindow.willEnterFullScreenNotification, nil),
            (NSWindow.willExitFullScreenNotification, nil),
        ]

        observers = notifications.map { notification, object in
            notificationCenter.addObserver(
                forName: notification,
                object: object,
                queue: .main,
                using: stateChangeHandler
            )
        }

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
            if windowMatcher.isFullscreen(windowBounds: window.bounds, screenFrames: screens) {
                setFullscreenState(true)
                return
            }
        }

        setFullscreenState(false)
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

struct FullscreenWindowMatcher {
    func isFullscreen(windowBounds: CGRect, screenFrames: [CGRect], tolerance: CGFloat = 1) -> Bool {
        screenFrames.contains { matches(windowBounds, screenFrame: $0, tolerance: tolerance) }
    }

    private func matches(_ windowBounds: CGRect, screenFrame: CGRect, tolerance: CGFloat) -> Bool {
        abs(windowBounds.width - screenFrame.width) < tolerance
            && abs(windowBounds.height - screenFrame.height) < tolerance
            && abs(windowBounds.origin.x - screenFrame.origin.x) < tolerance
            && abs(windowBounds.origin.y - screenFrame.origin.y) < tolerance
    }
}
