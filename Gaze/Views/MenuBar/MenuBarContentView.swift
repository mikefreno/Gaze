//
//  MenuBarContentView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

// Hover button style for menubar items
struct MenuBarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        configuration.isPressed
                            ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1)
                    )
                    .opacity(configuration.isPressed ? 1 : 0)
            )
            .contentShape(Rectangle())
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct MenuBarHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(
                isHovered ? .regular.tint(.accentColor.opacity(0.5)).interactive() : .regular,
                in: .rect(cornerRadius: 6)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .animation(.easeInOut(duration: 0.05), value: configuration.isPressed)
    }
}

struct MenuBarContentView: View {
    @ObservedObject var timerEngine: TimerEngine
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    var onQuit: () -> Void
    var onOpenSettings: () -> Void
    var onOpenSettingsTab: (Int) -> Void
    var onOpenOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "eye.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Gaze")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding()

            Divider()

            // Timer Status
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
                            },
                            onDevTrigger: {
                                timerEngine.triggerReminder(for: timerType)
                            },
                            onTap: {
                                onOpenSettingsTab(timerType.tabIndex)
                            }
                        )
                    } else {
                        InactiveTimerRow(
                            type: timerType,
                            onTap: {
                                onOpenSettingsTab(timerType.tabIndex)
                            }
                        )
                    }
                }
                
                // Show user timers if any exist and are enabled
                ForEach(settingsManager.settings.userTimers.filter { $0.enabled }, id: \.id) { userTimer in
                    UserTimerStatusRow(
                        timer: userTimer,
                        state: nil, // We'll implement proper state tracking later
                        onTap: {
                            onOpenSettingsTab(3) // Switch to User Timers tab
                        }
                    )
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Controls
            VStack(spacing: 4) {
                // Show "Complete Onboarding" button if not completed
                if !settingsManager.settings.hasCompletedOnboarding {
                    Button(action: {
                        onOpenOnboarding()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Complete Onboarding")
                            Spacer()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(MenuBarHoverButtonStyle())
                }
                
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
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(MenuBarHoverButtonStyle())

                Button(action: {
                    onOpenSettings()
                }) {
                    HStack {
                        Image(systemName: "gearshape")
                        Text("Settings...")
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .buttonStyle(MenuBarHoverButtonStyle())
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)

            Divider()

            // Quit
            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                        .foregroundColor(.red)
                    Text("Quit Gaze")
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .buttonStyle(MenuBarHoverButtonStyle())
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("CloseMenuBarPopover"))) { _ in
            dismiss()
        }
    }

    private var isPaused: Bool {
        timerEngine.timerStates.values.first?.isPaused ?? false
    }
}

struct TimerStatusRow: View {
    let type: TimerType
    let state: TimerState
    var onSkip: () -> Void
    var onDevTrigger: (() -> Void)? = nil
    var onTap: (() -> Void)? = nil
    @State private var isHoveredSkip = false
    @State private var isHoveredDevTrigger = false
    @State private var isHoveredBody = false

    var body: some View {
        HStack {
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
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?()
            }

            #if DEBUG
                if let onDevTrigger = onDevTrigger {
                    Button(action: onDevTrigger) {
                        Image(systemName: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(
                        isHoveredDevTrigger ? .regular.tint(.yellow.opacity(0.5)) : .regular,
                        in: .circle
                    )
                    .help("Trigger \(type.displayName) reminder now (dev)")
                    .onHover { hovering in
                        isHoveredDevTrigger = hovering
                    }
                }
            #endif

            Button(action: onSkip) {
                Image(systemName: "forward.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .glassEffect(
                isHoveredSkip ? .regular.tint(.accentColor.opacity(0.5)) : .regular,
                in: .circle
            )
            .help("Skip to next \(type.displayName) reminder")
            .onHover { hovering in
                isHoveredSkip = hovering
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffect(
            isHoveredBody ? .regular.tint(.accentColor.opacity(0.5)) : .regular,
            in: .rect(cornerRadius: 6)
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHoveredBody = hovering
        }
        .help(tooltipText)
    }

    private var tooltipText: String {
        type.tooltipText
    }

    private var iconColor: Color {
        switch type {
        case .lookAway: return .accentColor
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

struct InactiveTimerRow: View {
    let type: TimerType
    var onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: type.iconName)
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .padding(6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isHovered ? .regular.tint(.accentColor.opacity(0.5)) : .regular,
            in: .rect(cornerRadius: 6)
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Enable \(type.displayName) reminders")
    }
}

struct UserTimerStatusRow: View {
    let timer: UserTimer
    let state: TimerState?
    var onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack {
                Circle()
                    .fill(timer.color)
                    .frame(width: 8, height: 8)
                
                Image(systemName: "clock.fill")
                    .foregroundColor(timer.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if let state = state {
                        Text(timeRemaining(state))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    } else {
                        Text(timer.enabled ? "Not active" : "Disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: timer.type == .subtle ? "eye.circle" : "rectangle.on.rectangle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .glassEffect(
            isHovered ? .regular.tint(timer.color.opacity(0.3)) : .regular,
            in: .rect(cornerRadius: 6)
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltipText)
    }

    private var tooltipText: String {
        let typeText = timer.type == .subtle ? "Subtle" : "Overlay"
        let durationText = "\(timer.timeOnScreenSeconds)s on screen"
        let statusText = timer.enabled ? "" : " (Disabled)"
        return "\(typeText) timer - \(durationText)\(statusText)"
    }

    private func timeRemaining(_ state: TimerState) -> String {
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

#Preview("Menu Bar Content") {
    let settingsManager = SettingsManager.shared
    let timerEngine = TimerEngine(settingsManager: settingsManager)
    MenuBarContentView(
        timerEngine: timerEngine,
        settingsManager: settingsManager,
        onQuit: {},
        onOpenSettings: {},
        onOpenSettingsTab: { _ in },
        onOpenOnboarding: {}
    )
}