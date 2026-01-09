//
//  AnimatedFaceView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI
import Combine

struct AnimatedFaceView: View {
    @State private var eyeOffset: CGSize = .zero
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Face circle
            Circle()
                .stroke(Color.accentColor, lineWidth: size * 0.04)
                .frame(width: size, height: size)
            
            // Eyes
            HStack(spacing: size * 0.2) {
                Eye(offset: eyeOffset, size: size * 0.15)
                Eye(offset: eyeOffset, size: size * 0.15)
            }
            .offset(y: -size * 0.1)
            
            // Smile
            Arc(startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
                .stroke(Color.accentColor, lineWidth: size * 0.04)
                .frame(width: size * 0.5, height: size * 0.3)
                .offset(y: size * 0.15)
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Continuous eye movement animation using spring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animateEyeMovement()
        }
    }
    
    private func animateEyeMovement() {
        // Random, smooth eye movement using spring animation for natural effect
        let randomOffset = CGSize(
            width: CGFloat.random(in: -10...10),
            height: CGFloat.random(in: -5...5)
        )
        
        withAnimation(.spring(duration: 1.2, bounce: 0.2)) {
            eyeOffset = randomOffset
        }
        
        // Schedule next animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            animateEyeMovement()
        }
    }
}

struct Eye: View {
    let offset: CGSize
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor, lineWidth: size * 0.15)
                .frame(width: size, height: size)
            
            Circle()
                .fill(Color.accentColor)
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(offset)
        }
    }
}

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    var clockwise: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: clockwise
        )
        return path
    }
}

#Preview("Animated Face") {
    AnimatedFaceView(size: 200)
        .frame(width: 400, height: 400)
}