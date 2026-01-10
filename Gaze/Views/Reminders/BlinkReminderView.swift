//
//  BlinkReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import Lottie
import SwiftUI

struct BlinkReminderView: View {
    let sizePercentage: Double
    var onDismiss: () -> Void

    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0
    @State private var shouldShowAnimation = false

    private let screenHeight = NSScreen.main?.frame.height ?? 800
    private let screenWidth = NSScreen.main?.frame.width ?? 1200

    private var baseSize: CGFloat {
        screenWidth * (sizePercentage / 100.0)
    }

    var body: some View {
        VStack {
            if shouldShowAnimation {
                GazeLottieView(
                    animationName: AnimationAsset.blink.fileName,
                    loopMode: .playOnce,
                    animationSpeed: 1.0,
                    onAnimationFinish: { completed in
                        if completed {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                fadeOut()
                            }
                        }
                    }
                )
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(scale)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            }
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, screenHeight * 0.1)
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 1.0
            scale = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldShowAnimation = true
        }
    }

    private func fadeOut() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            scale = 0.7
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview("Blink Reminder") {
    BlinkReminderView(sizePercentage: 15.0, onDismiss: {})
        .frame(width: 800, height: 600)
}

#Preview("Blink Reminder") {
    BlinkReminderView(sizePercentage: 15.0, onDismiss: {})
        .frame(width: 800, height: 600)
}
