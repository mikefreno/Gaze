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
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            
            InfoBox(text: "We blink much less when focusing on screens. Regular blink reminders help prevent dry eyes")
            
            Spacer()
        }
        .frame(width: 600, height: 450)
        .padding()
        .background(.clear)
    }
}

#Preview("Blink Setup - Enabled") {
    BlinkSetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(5)
    )
}

#Preview("Blink Setup - Disabled") {
    BlinkSetupView(
        enabled: .constant(false),
        intervalMinutes: .constant(5)
    )
}
