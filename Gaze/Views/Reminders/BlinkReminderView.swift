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
    @State private var blinkState: BlinkState = .open
    @State private var blinkCount = 0
    
    private let screenHeight = NSScreen.main?.frame.height ?? 800
    private let screenWidth = NSScreen.main?.frame.width ?? 1200
    
    enum BlinkState {
        case open
        case closed
    }
    
    var body: some View {
        VStack {
            Image(systemName: blinkState == .open ? "eye.circle" : "eye.slash.circle")
                .font(.system(size: scale))
                .foregroundColor(.accentColor)
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
            scale = screenWidth * 0.1
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
            // Close eyes
            withAnimation(.linear(duration: blinkDuration)) {
                blinkState = .closed
            }
            
            // Open eyes
            DispatchQueue.main.asyncAfter(deadline: .now() + blinkDuration) {
                withAnimation(.linear(duration: blinkDuration)) {
                    blinkState = .open
                }
                
                blinkCount += 1
                
                if blinkCount < 2 {
                    // Pause before next blink
                    DispatchQueue.main.asyncAfter(deadline: .now() + pauseBetweenBlinks) {
                        blink()
                    }
                } else {
                    // Fade out after all blinks
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        fadeOut()
                    }
                }
            }
        }
        
        blink()
    }
    
    private func fadeOut() {
        withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0
            scale = screenWidth * 0.05
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
