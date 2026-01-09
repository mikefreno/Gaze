//
//  BlinkReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI
import Lottie

struct BlinkReminderView: View {
    var onDismiss: () -> Void
    
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0
    
    private let screenHeight = NSScreen.main?.frame.height ?? 800
    private let screenWidth = NSScreen.main?.frame.width ?? 1200
    
    var body: some View {
        VStack {
            LottieView(
                animationName: AnimationAsset.blink.fileName,
                loopMode: .playOnce,
                animationSpeed: 1.0
            )
            .frame(width: scale, height: scale)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, screenHeight * 0.1)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Fade in and grow
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 1.0
            scale = screenWidth * 0.15
        }
        
        // Animation duration (2 seconds for double blink) + hold time
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
            fadeOut()
        }
    }
    
    private func fadeOut() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            scale = screenWidth * 0.1
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

#Preview("Blink Reminder") {
    BlinkReminderView(onDismiss: {})
        .frame(width: 800, height: 600)
}

#Preview("Blink Reminder") {
    BlinkReminderView(onDismiss: {})
        .frame(width: 800, height: 600)
}
