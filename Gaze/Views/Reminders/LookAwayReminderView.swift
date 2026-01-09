//
//  LookAwayReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct LookAwayReminderView: View {
    let countdownSeconds: Int
    var onDismiss: () -> Void
    
    @State private var remainingSeconds: Int
    @State private var timer: Timer?
    
    init(countdownSeconds: Int, onDismiss: @escaping () -> Void) {
        self.countdownSeconds = countdownSeconds
        self.onDismiss = onDismiss
        self._remainingSeconds = State(initialValue: countdownSeconds)
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent dark background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text("Look Away")
                    .font(.system(size: 64, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Look at something 20 feet away")
                    .font(.system(size: 28))
                    .foregroundColor(.white.opacity(0.9))
                
                AnimatedFaceView(size: 200)
                    .padding(.vertical, 30)
                
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
                        .foregroundColor(.white)
                        .monospacedDigit()
                }
                
                Text("Press ESC or Space to skip")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Skip button in corner
            VStack {
                HStack {
                    Spacer()
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .padding(30)
                }
                Spacer()
            }
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onKeyPress(.escape) {
            dismiss()
            return .handled
        }
        .onKeyPress(.space) {
            dismiss()
            return .handled
        }
    }
    
    private var progress: CGFloat {
        CGFloat(remainingSeconds) / CGFloat(countdownSeconds)
    }
    
    private func startCountdown() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingSeconds > 0 {
                remainingSeconds -= 1
            } else {
                dismiss()
            }
        }
    }
    
    private func dismiss() {
        timer?.invalidate()
        onDismiss()
    }
}

#Preview("Look Away Reminder") {
    LookAwayReminderView(countdownSeconds: 20, onDismiss: {})
}
