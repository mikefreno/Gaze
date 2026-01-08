//
//  PostureReminderView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct PostureReminderView: View {
    var onDismiss: () -> Void
    
    @State private var scale: CGFloat = 0
    @State private var yOffset: CGFloat = 0
    @State private var opacity: Double = 0
    
    private let screenHeight = NSScreen.main?.frame.height ?? 800
    private let screenWidth = NSScreen.main?.frame.width ?? 1200
    
    var body: some View {
        VStack {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: scale))
                .foregroundColor(.black)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
        .opacity(opacity)
        .offset(y: yOffset)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, screenHeight * 0.1)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Phase 1: Fade in + Grow to 10% screen width
        withAnimation(.easeOut(duration: 0.4)) {
            opacity = 1.0
            scale = screenWidth * 0.1
        }
        
        // Phase 2: Hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4 + 0.5) {
            // Phase 3: Shrink to 5%
            withAnimation(.easeInOut(duration: 0.3)) {
                scale = screenWidth * 0.05
            }
            
            // Phase 4: Shoot upward
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.4)) {
                    yOffset = -screenHeight
                    opacity = 0
                }
                
                // Dismiss after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    onDismiss()
                }
            }
        }
    }
}

#Preview {
    PostureReminderView(onDismiss: {})
        .frame(width: 800, height: 600)
}
