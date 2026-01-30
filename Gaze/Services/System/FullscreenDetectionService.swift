//
//  FullscreenDetectionService.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import AppKit
import Combine
import Foundation
import MacroVisionKit

final class FullscreenDetectionService: ObservableObject {
    @Published private(set) var isFullscreenActive = false

    private var fullscreenTask: Task<Void, Never>?
    private let permissionManager: ScreenCapturePermissionManaging
    #if canImport(MacroVisionKit)
        private let monitor = FullScreenMonitor.shared
    #endif

    init(
        permissionManager: ScreenCapturePermissionManaging
    ) {
        self.permissionManager = permissionManager
        startMonitoring()
    }

    /// Convenience initializer using default services
    convenience init() {
        self.init(
            permissionManager: ScreenCapturePermissionManager.shared
        )
    }

    // Factory method to safely create instances from non-main actor contexts
    static func create(
        permissionManager: ScreenCapturePermissionManaging? = nil
    ) async -> FullscreenDetectionService {
        await MainActor.run {
            return FullscreenDetectionService(
                permissionManager: permissionManager ?? ScreenCapturePermissionManager.shared
            )
        }
    }

    deinit {
        fullscreenTask?.cancel()
    }

    private func canReadWindowInfo() -> Bool {
        guard permissionManager.authorizationStatus.isAuthorized else {
            setFullscreenState(false)
            return false
        }

        return true
    }

    private func startMonitoring() {
        fullscreenTask = Task { [weak self] in
            guard let self else { return }
            let stream = await monitor.spaceChanges()
            for await spaces in stream {
                guard self.canReadWindowInfo() else { continue }
                self.setFullscreenState(!spaces.isEmpty)
            }
        }

        forceUpdate()
    }

    fileprivate func setFullscreenState(_ isActive: Bool) {
        guard isFullscreenActive != isActive else { return }
        isFullscreenActive = isActive
        print("🖥️ Fullscreen state updated: \(isActive ? "ACTIVE" : "INACTIVE")")
    }

    func forceUpdate() {
        Task { [weak self] in
            guard let self else { return }
            guard self.canReadWindowInfo() else { return }
            let spaces = await monitor.detectFullscreenApps()
            self.setFullscreenState(!spaces.isEmpty)
        }
    }

    #if DEBUG
        func simulateFullscreenStateForTesting(_ isActive: Bool) {
            setFullscreenState(isActive)
        }
    #endif
}
