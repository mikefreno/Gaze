//
//  MenuBarContentView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsManager: SettingsManager
    var onQuit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Gaze")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding()
            
            Divider()
            
            // Timer Status
            if !timerEngine.timerStates.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Timers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    ForEach(TimerType.allCases) { timerType in
                        if let state = timerEngine.timerStates[timerType] {
                            TimerStatusRow(
                                type: timerType,
                                state: state,
                                onSkip: {
                                    timerEngine.skipNext(type: timerType)
                                }
                            )
                        }
                    }
                }
                .padding(.bottom, 8)
                
                Divider()
            }
            
            // Controls
            VStack(spacing: 8) {
                Button(action: {
                    if timerEngine.timerStates.values.first?.isPaused == true {
                        timerEngine.resume()
                    } else {
                        timerEngine.pause()
                    }
                }) {
                    HStack {
                        Image(systemName: isPaused ? "play.circle" : "pause.circle")
                        Text(isPaused ? "Resume All Timers" : "Pause All Timers")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                
                Button(action: {
                    // TODO: Open settings window
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Settings...")
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Quit
            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Gaze")
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding()
        }
        .frame(width: 300)
    }
    
    private var isPaused: Bool {
        timerEngine.timerStates.values.first?.isPaused ?? false
    }
}

struct TimerStatusRow: View {
    let type: TimerType
    let state: TimerState
    var onSkip: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: type.iconName)
                .foregroundColor(iconColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(timeRemaining)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            
            Spacer()
            
            Button(action: onSkip) {
                Image(systemName: "forward.fill")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("Skip to next \(type.displayName) reminder")
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private var iconColor: Color {
        switch type {
        case .lookAway: return .blue
        case .blink: return .green
        case .posture: return .orange
        }
    }
    
    private var timeRemaining: String {
        let seconds = state.remainingSeconds
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return String(format: "%dh %dm", hours, remainingMinutes)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, remainingSeconds)
        } else {
            return String(format: "%ds", remainingSeconds)
        }
    }
}

#Preview {
    MenuBarContentView(
        timerEngine: TimerEngine(settingsManager: .shared),
        settingsManager: .shared,
        onQuit: {}
    )
}
