//
//  CompletionView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct CompletionView: View {
    var onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("You're All Set!")
                .font(.system(size: 36, weight: .bold))
            
            Text("Gaze will now help you take care of your eyes and posture")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What happens next:")
                    .font(.headline)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Image(systemName: "menubar.rectangle")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Gaze will appear in your menu bar")
                        .font(.subheadline)
                }
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Timers will start automatically")
                        .font(.subheadline)
                }
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("Adjust settings anytime from the menu bar")
                        .font(.subheadline)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
            
            Button(action: onComplete) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
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

#Preview {
    CompletionView(onComplete: {})
}
