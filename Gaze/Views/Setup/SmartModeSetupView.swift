//
//  SmartModeSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import SwiftUI

struct SmartModeSetupView: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header section
            VStack(spacing: 16) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Smart Mode")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Automatically manage timers based on your activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 30)
            
            // Vertically centered content
            Spacer()
            
            VStack(spacing: 24) {
                // Auto-pause on fullscreen toggle
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { settingsManager.settings.smartMode.autoPauseOnFullscreen },
                        set: { settingsManager.settings.smartMode.autoPauseOnFullscreen = $0 }
                    )) {
                        HStack {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .foregroundColor(.blue)
                            Text("Auto-pause on Fullscreen")
                                .font(.headline)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Text("Timers will automatically pause when you enter fullscreen mode (videos, games, presentations)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 8))
                
                // Auto-pause on idle toggle with threshold slider
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { settingsManager.settings.smartMode.autoPauseOnIdle },
                        set: { settingsManager.settings.smartMode.autoPauseOnIdle = $0 }
                    )) {
                        HStack {
                            Image(systemName: "moon.zzz.fill")
                                .foregroundColor(.indigo)
                            Text("Auto-pause on Idle")
                                .font(.headline)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Text("Timers will pause when you're inactive for more than the threshold below")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                    
                    if settingsManager.settings.smartMode.autoPauseOnIdle {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Idle Threshold:")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(settingsManager.settings.smartMode.idleThresholdMinutes) min")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.smartMode.idleThresholdMinutes) },
                                    set: { settingsManager.settings.smartMode.idleThresholdMinutes = Int($0) }
                                ),
                                in: 1...30,
                                step: 1
                            )
                        }
                        .padding(.top, 8)
                        .padding(.leading, 28)
                    }
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 8))
                
                // Usage tracking toggle with reset threshold
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { settingsManager.settings.smartMode.trackUsage },
                        set: { settingsManager.settings.smartMode.trackUsage = $0 }
                    )) {
                        HStack {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .foregroundColor(.green)
                            Text("Track Usage Statistics")
                                .font(.headline)
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Text("Monitor active and idle time, with automatic reset after the specified duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.leading, 28)
                    
                    if settingsManager.settings.smartMode.trackUsage {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reset After:")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(settingsManager.settings.smartMode.usageResetAfterMinutes) min")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(
                                value: Binding(
                                    get: { Double(settingsManager.settings.smartMode.usageResetAfterMinutes) },
                                    set: { settingsManager.settings.smartMode.usageResetAfterMinutes = Int($0) }
                                ),
                                in: 15...240,
                                step: 15
                            )
                        }
                        .padding(.top, 8)
                        .padding(.leading, 28)
                    }
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 8))
            }
            .frame(maxWidth: 600)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }
}

#Preview {
    SmartModeSetupView(settingsManager: SettingsManager.shared)
}
