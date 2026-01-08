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
    @State private var blinkState: BlinkState = .open
    @State private var blinkCount = 0
    
    enum BlinkState {
        case open
        case closed
    }
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                .frame(width: 100, height: 100)
                .overlay(
                    BlinkingFace(isOpen: blinkState == .open)
                )
        }
        .opacity(opacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, NSScreen.main?.frame.height ?? 800 * 0.1)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Fade in
        withAnimation(.easeIn(duration: 0.3)) {
            opacity = 1.0
        }
        
        // Start blinking after fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            performBlinks()
        }
    }
    
    private func performBlinks() {
        let blinkDuration = 0.1
        let pauseBetweenBlinks = 0.5
        
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
                
                if blinkCount < 3 {
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
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

struct BlinkingFace: View {
    let isOpen: Bool
    
    var body: some View {
        ZStack {
            // Simple face
            Circle()
                .fill(Color.yellow)
                .frame(width: 60, height: 60)
            
            // Eyes
            HStack(spacing: 12) {
                if isOpen {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                    Circle()
                        .fill(Color.black)
                        .frame(width: 8, height: 8)
                } else {
                    // Closed eyes (lines)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 10, height: 2)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: 10, height: 2)
                }
            }
            .offset(y: -8)
            
            // Smile
            Arc(startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                .stroke(Color.black, lineWidth: 2)
                .frame(width: 30, height: 15)
                .offset(y: 10)
        }
    }
}

#Preview {
    BlinkReminderView(onDismiss: {})
        .frame(width: 800, height: 600)
}
