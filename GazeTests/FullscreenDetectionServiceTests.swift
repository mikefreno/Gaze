//
//  FullscreenDetectionServiceTests.swift
//  GazeTests
//
//  Created by ChatGPT on 1/14/26.
//

import Combine
import CoreGraphics
import XCTest
@testable import Gaze

@MainActor
final class FullscreenDetectionServiceTests: XCTestCase {
    func testPermissionDeniedKeepsStateFalse() {
        let mockManager = MockPermissionManager(status: ScreenCaptureAuthorizationStatus.denied)
        let service = FullscreenDetectionService(permissionManager: mockManager)

        let expectation = expectation(description: "No change")
        expectation.isInverted = true

        let cancellable = service.$isFullscreenActive
            .dropFirst()
            .sink { _ in
                expectation.fulfill()
            }

        service.forceUpdate()

        wait(for: [expectation], timeout: 0.5)
        cancellable.cancel()
    }

    func testFullscreenStateBecomesTrueWhenWindowMatchesScreen() {
        let mockManager = MockPermissionManager(status: ScreenCaptureAuthorizationStatus.authorized)
        let environment = MockFullscreenEnvironment(
            frontmostPID: 42,
            windowDescriptors: [
                FullscreenWindowDescriptor(
                    ownerPID: 42,
                    layer: 0,
                    bounds: CGRect(x: 0, y: 0, width: 1920, height: 1080)
                )
            ],
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let service = FullscreenDetectionService(
            permissionManager: mockManager,
            environmentProvider: environment
        )

        let expectation = expectation(description: "Fullscreen detected")

        let cancellable = service.$isFullscreenActive
            .dropFirst()
            .sink { isActive in
                if isActive {
                    expectation.fulfill()
                }
            }

        service.forceUpdate()

        wait(for: [expectation], timeout: 0.5)
        cancellable.cancel()
    }

    func testFullscreenStateStaysFalseWhenWindowDoesNotMatchScreen() {
        let mockManager = MockPermissionManager(status: ScreenCaptureAuthorizationStatus.authorized)
        let environment = MockFullscreenEnvironment(
            frontmostPID: 42,
            windowDescriptors: [
                FullscreenWindowDescriptor(
                    ownerPID: 42,
                    layer: 0,
                    bounds: CGRect(x: 100, y: 100, width: 800, height: 600)
                )
            ],
            screenFrames: [CGRect(x: 0, y: 0, width: 1920, height: 1080)]
        )

        let service = FullscreenDetectionService(
            permissionManager: mockManager,
            environmentProvider: environment
        )

        let expectation = expectation(description: "No fullscreen")
        expectation.isInverted = true

        let cancellable = service.$isFullscreenActive
            .dropFirst()
            .sink { isActive in
                if isActive {
                    expectation.fulfill()
                }
            }

        service.forceUpdate()

        wait(for: [expectation], timeout: 0.5)
        cancellable.cancel()
    }
}

@MainActor
private final class MockPermissionManager: ScreenCapturePermissionManaging {
    var authorizationStatus: ScreenCaptureAuthorizationStatus
    var authorizationStatusPublisher: AnyPublisher<ScreenCaptureAuthorizationStatus, Never> {
        Just(authorizationStatus).eraseToAnyPublisher()
    }

    init(status: ScreenCaptureAuthorizationStatus) {
        self.authorizationStatus = status
    }

    func refreshStatus() {}
    func requestAuthorizationIfNeeded() {}
    func openSystemSettings() {}
}
