//
//  PostureSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct PostureSetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "figure.stand")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Posture Reminder")
                .font(.system(size: 28, weight: .bold))
            
            Text("Maintain proper ergonomics")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 20) {
                Toggle("Enable Posture Reminders", isOn: $enabled)
                    .font(.headline)
                
                if enabled {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Remind me every:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(intervalMinutes) },
                                set: { intervalMinutes = Int($0) }
                            ), in: 15...60, step: 5)
                            
                            Text("\(intervalMinutes) min")
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            InfoBox(text: "Regular posture checks help prevent back and neck pain from prolonged sitting")
            
            Spacer()
            
            Button(action: onContinue) {
                Text("Continue")
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

#Preview {
    PostureSetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(30),
        onContinue: {}
    )
}
