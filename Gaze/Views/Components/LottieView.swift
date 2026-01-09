//
//  LottieView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI
import Lottie

struct LottieView: NSViewRepresentable {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    
    init(
        animationName: String,
        loopMode: LottieLoopMode = .playOnce,
        animationSpeed: CGFloat = 1.0
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
    }
    
    func makeNSView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        if let animation = LottieAnimation.named(animationName) {
            animationView.animation = animation
            animationView.loopMode = loopMode
            animationView.animationSpeed = animationSpeed
            animationView.backgroundBehavior = .pauseAndRestore
            animationView.play()
        }
        
        return animationView
    }
    
    func updateNSView(_ nsView: LottieAnimationView, context: Context) {
        guard nsView.animation == nil || nsView.isAnimationPlaying == false else {
            return
        }
        
        if let animation = LottieAnimation.named(animationName) {
            nsView.animation = animation
            nsView.loopMode = loopMode
            nsView.animationSpeed = animationSpeed
            nsView.play()
        }
    }
}

#Preview("Lottie Preview") {
    VStack(spacing: 20) {
        LottieView(animationName: "blink")
            .frame(width: 200, height: 200)
        
        LottieView(animationName: "look-away", loopMode: .loop)
            .frame(width: 200, height: 200)
        
        LottieView(animationName: "posture")
            .frame(width: 200, height: 200)
    }
    .frame(width: 600, height: 800)
}
