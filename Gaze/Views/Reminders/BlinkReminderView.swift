//
//  BlinkReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct BlinkReminderView: View {
    var onDismiss: () -> Void
    
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0
    @State private var blinkProgress: Double = 0
    @State private var blinkCount = 0
    
    private let screenHeight = NSScreen.main?.frame.height ?? 800
    private let screenWidth = NSScreen.main?.frame.width ?? 1200
    
    var body: some View {
        VStack {
            // Custom eye design for more polished look
            ZStack {
                // Eye outline
                Circle()
                    .stroke(Color.accentColor, lineWidth: 4)
                    .frame(width: scale * 1.2, height: scale * 1.2)
                
                // Iris
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: scale * 0.6, height: scale * 0.6)
                
                // Pupil that moves with blink
                Circle()
                    .fill(.black)
                    .frame(width: scale * 0.25, height: scale * 0.25)
                    .offset(y: blinkProgress * -scale * 0.1) // Vertical movement during blink
            }
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, screenHeight * 0.1)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Fade in and grow with spring animation for natural feel
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            opacity = 1.0
            scale = screenWidth * 0.12
        }
        
        // Start blinking after fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            performBlinks()
        }
    }
    
    private func performBlinks() {
        let blinkDuration = 0.15
        let pauseBetweenBlinks = 0.2
        
        func blink() {
            // Close eyes with spring animation for natural movement
            withAnimation(.spring(duration: blinkDuration, bounce: 0.0)) {
                blinkProgress = 1.0
            }
            
            // Open eyes
            DispatchQueue.main.asyncAfter(deadline: .now() + blinkDuration) {
                withAnimation(.spring(duration: blinkDuration, bounce: 0.0)) {
                    blinkProgress = 0.0
                }
                
                blinkCount += 1
                
                if blinkCount < 2 {
                    // Pause before next blink
                    DispatchQueue.main.asyncAfter(deadline: .now() + pauseBetweenBlinks) {
                        blink()
                    }
                } else {
                    // Fade out after all blinks with smooth spring animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        fadeOut()
                    }
                }
            }
        }
        
        blink()
    }
    
    private func fadeOut() {
        withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
            opacity = 0
            scale = screenWidth * 0.08
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onDismiss()
        }
    }
}

#Preview("Blink Reminder") {
    BlinkReminderView(onDismiss: {})
        .frame(width: 800, height: 600)
}
