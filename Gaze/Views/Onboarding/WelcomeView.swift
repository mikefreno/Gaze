//
//  WelcomeView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct WelcomeView: View {
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "eye.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text("Welcome to Gaze")
                .font(.system(size: 36, weight: .bold))
            
            Text("Take care of your eyes and posture")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "eye.circle", title: "Reduce Eye Strain", description: "Regular breaks help prevent digital eye strain")
                FeatureRow(icon: "eye.trianglebadge.exclamationmark", title: "Remember to Blink", description: "We blink less when focused on screens")
                FeatureRow(icon: "figure.stand", title: "Maintain Good Posture", description: "Gentle reminders to sit up straight")
            }
            .padding()
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Let's Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .frame(width: 600, height: 500)
        .padding()
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    WelcomeView(onContinue: {})
}
