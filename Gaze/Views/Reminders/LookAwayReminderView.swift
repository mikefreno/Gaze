//
//  LookAwayReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import AppKit
import Lottie
import SwiftUI

struct LookAwayReminderView: View {
    let countdownSeconds: Int
    var onDismiss: () -> Void
    var enforceModeService: EnforceModeService?

    @State private var remainingSeconds: Int
    @State private var remainingTime: TimeInterval
    @State private var timer: Timer?
    @State private var keyMonitor: Any?

    init(
        countdownSeconds: Int,
        enforceModeService: EnforceModeService? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.countdownSeconds = countdownSeconds
        self.enforceModeService = enforceModeService
        self.onDismiss = onDismiss
        self._remainingSeconds = State(initialValue: countdownSeconds)
        self._remainingTime = State(initialValue: TimeInterval(countdownSeconds))
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Text("Look Away")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)

                Text("Look at something 20 feet away")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.9))

                GazeLottieView(
                    animationName: AnimationAsset.lookAway.fileName,
                    loopMode: .loop,
                    animationSpeed: 0.75
                )
                .frame(width: 200, height: 200)
                .padding(.vertical, 30)

                if let enforceModeService, enforceModeService.isEnforceModeEnabled {
                    let shouldShowWarning = enforceModeService.shouldAdvanceLookAwayCountdown() == false
                    if shouldShowWarning {
                        Text("Look away to continue")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                // Countdown display
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    Text("\(remainingSeconds)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .accessibilityIdentifier(AccessibilityIdentifiers.Reminders.countdownLabel)
                }

                Text("Press ESC or Space to skip")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Skip button in corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(AccessibilityIdentifiers.Reminders.dismissButton)
                    .padding(30)
                }
                Spacer()
            }
        }
        .accessibilityIdentifier(AccessibilityIdentifiers.Reminders.lookAwayView)
        .onAppear {
            startCountdown()
            setupKeyMonitor()
        }
        .onDisappear {
            timer?.invalidate()
            removeKeyMonitor()
        }
    }

    private var progress: CGFloat {
        CGFloat(remainingTime) / CGFloat(countdownSeconds)
    }

    private func startCountdown() {
        let tickInterval: TimeInterval = 0.25
        let timer = Timer(timeInterval: tickInterval, repeats: true) { [self] _ in
            guard remainingTime > 0 else {
                dismiss()
                return
            }

            let shouldAdvance = enforceModeService?.shouldAdvanceLookAwayCountdown() ?? true
            if shouldAdvance {
                remainingTime = max(0, remainingTime - tickInterval)
                remainingSeconds = max(0, Int(ceil(remainingTime)))
            }
        }
        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }

    private func dismiss() {
        timer?.invalidate()
        onDismiss()
    }

    private func setupKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {  // ESC key
                dismiss()
                return nil
            } else if event.keyCode == 49 {  // Space key
                dismiss()
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

#Preview("Look Away Reminder") {
    LookAwayReminderView(countdownSeconds: 20, onDismiss: {})
}
