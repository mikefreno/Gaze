//
//  UserTimerReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/11/26.
//

import SwiftUI

struct UserTimerReminderView: View {
    let timer: UserTimer
    let sizePercentage: Double
    var onDismiss: () -> Void

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    private let screenHeight = NSScreen.main?.frame.height ?? 800
    private let screenWidth = NSScreen.main?.frame.width ?? 1200

    private var baseSize: CGFloat {
        screenWidth * (sizePercentage / 100.0)
    }

    var body: some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: baseSize * 0.4))
                    .foregroundStyle(timer.color)

                if let message = timer.message, !message.isEmpty {
                    Text(message)
                        .font(.system(size: baseSize * 0.24))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .scaleEffect(scale * 2)
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, screenHeight * 0.075)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Fade in and grow
        withAnimation(.easeOut(duration: 0.4)) {
            opacity = 1.0
            scale = 1.0
        }

        // Subtle reminders always display for 3 seconds
        let holdDuration = 3.0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + holdDuration) {
            withAnimation(.easeIn(duration: 0.4)) {
                opacity = 0
                scale = 0.8
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                onDismiss()
            }
        }
    }
}

#Preview("User Timer Reminder") {
    UserTimerReminderView(
        timer: UserTimer(
            title: "Stand Up",
            type: .subtle,
            timeOnScreenSeconds: 5,
            intervalMinutes: 30,
            message: "Time to stand and stretch!"
        ),
        sizePercentage: 10.0,
        onDismiss: {}
    )
    .frame(width: 800, height: 600)
}
