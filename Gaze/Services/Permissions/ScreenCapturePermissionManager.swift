//
//  ScreenCapturePermissionManager.swift
//  Gaze
//
//  Created by ChatGPT on 1/14/26.
//

import AppKit
import Combine
import CoreGraphics
import Foundation

public enum ScreenCaptureAuthorizationStatus: Equatable {
    case authorized
    case denied
    case notDetermined

    var isAuthorized: Bool {
        if case .authorized = self { return true }
        return false
    }
}

@MainActor
protocol ScreenCapturePermissionManaging: AnyObject {
    var authorizationStatus: ScreenCaptureAuthorizationStatus { get }
    var authorizationStatusPublisher: AnyPublisher<ScreenCaptureAuthorizationStatus, Never> { get }

    func refreshStatus()
    func requestAuthorizationIfNeeded()
    func openSystemSettings()
}

@MainActor
final class ScreenCapturePermissionManager: ObservableObject, ScreenCapturePermissionManaging {
    static let shared = ScreenCapturePermissionManager()

    @Published private(set) var authorizationStatus: ScreenCaptureAuthorizationStatus =
        .notDetermined

    var authorizationStatusPublisher: AnyPublisher<ScreenCaptureAuthorizationStatus, Never> {
        $authorizationStatus.eraseToAnyPublisher()
    }

    private let userDefaults: UserDefaults
    private let requestedKey = "gazeScreenCapturePermissionRequested"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        refreshStatus()
    }

    func refreshStatus() {
        if CGPreflightScreenCaptureAccess() {
            authorizationStatus = .authorized
        } else if userDefaults.bool(forKey: requestedKey) {
            authorizationStatus = .denied
        } else {
            authorizationStatus = .notDetermined
        }
    }

    func requestAuthorizationIfNeeded() {
        refreshStatus()

        guard authorizationStatus == .notDetermined else { return }

        userDefaults.set(true, forKey: requestedKey)
        let granted = CGRequestScreenCaptureAccess()
        authorizationStatus = granted ? .authorized : .denied
    }

    func openSystemSettings() {
        // Try different variations
        let possibleUrls = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenRecording",
            "x-apple.systempreferences:Privacy?ScreenRecording",
            "x-apple.systempreferences:com.apple.preference.security",
            "x-apple.systempreferences:Privacy",
            "x-apple.systempreferences:com.apple.preferences.security",
        ]

        for urlString in possibleUrls {
            if let url = URL(string: urlString),
                NSWorkspace.shared.open(url)
            {
                print("Successfully opened: \(urlString)")
                return
            }
        }

        print("All attempts failed")
    }
}
