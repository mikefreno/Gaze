//
//  UserTimerOverlayReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/11/26.
//

import AppKit
import SwiftUI

struct UserTimerOverlayReminderView: View {
    let timer: UserTimer
    var onDismiss: () -> Void
    var enforceModeService: EnforceModeService?

    @State private var remainingSeconds: Int
    @State private var remainingTime: TimeInterval
    @State private var countdownTimer: Timer?
    @State private var keyMonitor: Any?

    init(
        timer: UserTimer,
        enforceModeService: EnforceModeService? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.timer = timer
        self.enforceModeService = enforceModeService
        self.onDismiss = onDismiss
        self._remainingSeconds = State(initialValue: timer.timeOnScreenSeconds)
        self._remainingTime = State(initialValue: TimeInterval(timer.timeOnScreenSeconds))
    }

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Text(timer.title)
                    .font(.system(size: 64, weight: .bold))
                    .foregroundStyle(.white)

                if let message = timer.message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                if timer.enforceModeEnabled {
                    let shouldShowWarning = enforceModeService?.shouldAdvanceCountdown(for: timer) == false
                    if shouldShowWarning {
                        Text("Look away to continue")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                Image(systemName: "clock.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(timer.color)
                    .padding(.vertical, 30)

                // Countdown display
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(timer.color, lineWidth: 8)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)

                    Text("\(remainingSeconds)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                }

                Text("Press ESC or Space to dismiss")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Dismiss button in corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(30)
                }
                Spacer()
            }
        }
        .onAppear {
            startCountdown()
            setupKeyMonitor()
        }
        .onDisappear {
            countdownTimer?.invalidate()
            removeKeyMonitor()
        }
    }

    private var progress: CGFloat {
        guard timer.timeOnScreenSeconds > 0 else { return 0 }
        return CGFloat(remainingTime) / CGFloat(timer.timeOnScreenSeconds)
    }

    private func startCountdown() {
        let tickInterval: TimeInterval = 0.25
        let countdownTimer = Timer(timeInterval: tickInterval, repeats: true) { [self] _ in
            guard remainingTime > 0 else {
                dismiss()
                return
            }

            let shouldAdvance = enforceModeService?.shouldAdvanceCountdown(for: timer) ?? true
            if shouldAdvance {
                remainingTime = max(0, remainingTime - tickInterval)
                remainingSeconds = max(0, Int(ceil(remainingTime)))
            }
        }
        RunLoop.current.add(countdownTimer, forMode: .common)
        self.countdownTimer = countdownTimer
    }

    private func dismiss() {
        countdownTimer?.invalidate()
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

#Preview("User Timer Overlay Reminder") {
    UserTimerOverlayReminderView(
        timer: UserTimer(
            title: "Water Break",
            type: .overlay,
            timeOnScreenSeconds: 10,
            intervalMinutes: 60,
            message: "Time to drink some water and stay hydrated!"
        ),
        onDismiss: {}
    )
}
