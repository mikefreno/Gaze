//
//  EnforcePolicyEvaluator.swift
//  Gaze
//
//  Policy evaluation for enforce mode behavior.
//

import Foundation

enum ComplianceResult {
    case compliant
    case notCompliant
    case faceNotDetected
}

final class EnforcePolicyEvaluator {
    private let settingsProvider: any SettingsProviding

    init(settingsProvider: any SettingsProviding) {
        self.settingsProvider = settingsProvider
    }

    var isEnforcementEnabled: Bool {
        settingsProvider.isTimerEnabled(for: .lookAway)
    }

    func shouldEnforce(timerIdentifier: TimerIdentifier) -> Bool {
        guard isEnforcementEnabled else { return false }

        switch timerIdentifier {
        case .builtIn(let type):
            return type == .lookAway
        case .user:
            return false
        }
    }

    func shouldPreActivateCamera(
        timerIdentifier: TimerIdentifier,
        secondsRemaining: Int
    ) -> Bool {
        guard secondsRemaining <= 3 else { return false }
        return shouldEnforce(timerIdentifier: timerIdentifier)
    }

    func evaluateCompliance(
        isLookingAtScreen: Bool,
        faceDetected: Bool
    ) -> ComplianceResult {
        guard faceDetected else { return .faceNotDetected }
        return isLookingAtScreen ? .notCompliant : .compliant
    }
}
