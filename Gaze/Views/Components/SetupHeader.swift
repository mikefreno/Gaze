//
//  SetupHeader.swift
//  Gaze
//
//  Created by Mike Freno on 1/15/26.
//

import SwiftUI

struct SetupHeader: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 28, weight: .bold))
        }
        .padding(.top, 15)
        .padding(.bottom, 20)
    }
}

#Preview("SetupHeader") {
    VStack(spacing: 40) {
        SetupHeader(icon: "eye.fill", title: "Look Away Reminder", color: .accentColor)
        SetupHeader(icon: "eye.circle", title: "Blink Reminder", color: .green)
        SetupHeader(icon: "figure.stand", title: "Posture Reminder", color: .orange)
    }
}
