//
//  LookAwaySetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct LookAwaySetupView: View {
    @Binding var enabled: Bool
    @Binding var intervalMinutes: Int
    @Binding var countdownSeconds: Int
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "eye.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Look Away Reminder")
                .font(.system(size: 28, weight: .bold))
            
            InfoBox(text: "Suggested: 20-20-20 rule")
            
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
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            
            Text("You will be reminded every \(intervalMinutes) minutes to look in the distance for \(countdownSeconds) seconds")
            
            Spacer()
        }
        .frame(width: 600, height: 450)
        .padding()
        .background(.clear)
    }
}

struct InfoBox: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if let url = URL(string: "https://www.healthline.com/health/eye-health/20-20-20-rule") {
                    #if os(iOS)
                    UIApplication.shared.open(url)
                    #elseif os(macOS)
                    NSWorkspace.shared.open(url)
                    #endif
                }
            }) {
                Image(systemName: "info.circle")
                    .foregroundColor(.white)
            }.buttonStyle(.plain)
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 8))
    }
}

#Preview("Look Away Setup View") {
    LookAwaySetupView(
        enabled: .constant(true),
        intervalMinutes: .constant(20),
        countdownSeconds: .constant(20)
    )
}

#Preview("Info Box") {
    InfoBox(text: "This is an informational message that provides helpful context to the user.")
        .padding()
}
