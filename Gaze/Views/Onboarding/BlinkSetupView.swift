//
//  BlinkSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct BlinkSetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int
    var onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.circle")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Blink Reminder")
                .font(.system(size: 28, weight: .bold))
            
            Text("Keep your eyes hydrated")
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 20) {
                Toggle("Enable Blink Reminders", isOn: $enabled)
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
                            ), in: 1...15, step: 1)
                            
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
            
            InfoBox(text: "We blink much less when focusing on screens. Regular blink reminders help prevent dry eyes")
            
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
    BlinkSetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(5),
        onContinue: {}
    )
}
