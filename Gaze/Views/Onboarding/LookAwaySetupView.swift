//
//  LookAwaySetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct LookAwaySetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int
    @Binding var countdownSeconds: Int
    var onContinue: () -> Void
    var onBack: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Look Away Reminder")
                .font(.system(size: 28, weight: .bold))
            
            Text("Follow the 20-20-20 rule")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 20) {
                Toggle("Enable Look Away Reminders", isOn: $enabled)
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
                            ), in: 5...60, step: 5)
                            
                            Text("\(intervalMinutes) min")
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                        }
                        
                         Text("Look away for:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(value: Binding(
                                get: { Double(countdownSeconds) },
                                set: { countdownSeconds = Int($0) }
                            ), in: 10...30, step: 5)
                            
                            Text("\(countdownSeconds) sec")
                                .frame(width: 60, alignment: .trailing)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            InfoBox(text: "Every 20 minutes, look at something 20 feet away for 20 seconds to reduce eye strain")
            
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

struct InfoBox: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundColor(.blue)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

#Preview {
    LookAwaySetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(20),
        countdownSeconds: .constant(20),
        onContinue: {}
    )
}
