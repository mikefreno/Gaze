//
//  FullscreenDetectionServiceTests.swift
//  GazeTests
//
//  Created by ChatGPT on 1/14/26.
//

import Combine
import XCTest
@testable import Gaze

@MainActor
final class FullscreenDetectionServiceTests: XCTestCase {
    func testPermissionDeniedKeepsStateFalse() {
        let service = FullscreenDetectionService(permissionManager: MockPermissionManager(status: .denied))

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
