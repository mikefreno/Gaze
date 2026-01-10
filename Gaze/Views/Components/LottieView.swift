//
//  LottieView.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import Lottie
import SwiftUI

struct GazeLottieView: View {
    let animationName: String
    let loopMode: LottieLoopMode
    let animationSpeed: CGFloat
    let onAnimationFinish: ((Bool) -> Void)?

    init(
        animationName: String,
        loopMode: LottieLoopMode = .playOnce,
        animationSpeed: CGFloat = 1.0,
        onAnimationFinish: ((Bool) -> Void)? = nil
    ) {
        self.animationName = animationName
        self.loopMode = loopMode
        self.animationSpeed = animationSpeed
        self.onAnimationFinish = onAnimationFinish
    }

    var body: some View {
        if let animation = LottieAnimation.named(animationName) {
            LottieView(animation: animation)
                .playing(.fromProgress(nil, toProgress: 1, loopMode: loopMode))
                .animationSpeed(animationSpeed)
                .animationDidFinish { completed in
                    onAnimationFinish?(completed)
                }
        }
    }
}

#Preview("Lottie Preview") {
    VStack(spacing: 20) {
        GazeLottieView(animationName: "blink")
            .frame(width: 200, height: 200)

        GazeLottieView(animationName: "look-away", loopMode: .loop)
            .frame(width: 200, height: 200)

        GazeLottieView(animationName: "posture")
            .frame(width: 200, height: 200)
    }
    .frame(width: 600, height: 800)
}
