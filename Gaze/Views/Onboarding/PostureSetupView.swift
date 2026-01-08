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
    var onBack: (() -> Void)?
    
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
            .glassEffect(in: .rect(cornerRadius: 12))
            
            InfoBox(text: "Regular posture checks help prevent back and neck pain from prolonged sitting")
            
            Spacer()
            
            HStack(spacing: 12) {
                if let onBack = onBack {
                    Button(action: onBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive())
                }
                
                Button(action: onContinue) {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(.blue).interactive())
            }
            .padding(.horizontal, 40)
        }
        .frame(width: 600, height: 500)
        .padding()
        .background(.clear)
    }
}

#Preview {
    PostureSetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(30),
        onContinue: {},
        onBack: {}
    )
}
