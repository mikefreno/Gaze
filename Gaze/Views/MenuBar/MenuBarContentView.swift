//
//  MenuBarContentView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

// Wrapper to properly observe AppDelegate changes in MenuBarExtra
struct MenuBarContentWrapper: View {
    @ObservedObject var appDelegate: AppDelegate
    @ObservedObject var settingsManager: SettingsManager
    var onQuit: () -> Void
    var onOpenSettings: () -> Void
    var onOpenSettingsTab: (Int) -> Void
    var onOpenOnboarding: () -> Void

    var body: some View {
        MenuBarContentView(
            timerEngine: appDelegate.timerEngine,
            settingsManager: settingsManager,
            onQuit: onQuit,
            onOpenSettings: onOpenSettings,
            onOpenSettingsTab: onOpenSettingsTab,
            onOpenOnboarding: onOpenOnboarding
        )
    }
}

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
            .foregroundColor(isHovered ? .white : .primary)
            .glassEffectIfAvailable(
                isHovered
                    ? GlassStyle.regular.tint(.accentColor).interactive()
                    : GlassStyle.regular,
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
    var timerEngine: TimerEngine?
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    var onQuit: () -> Void
    var onOpenSettings: () -> Void
    var onOpenSettingsTab: (Int) -> Void
    var onOpenOnboarding: () -> Void

    var body: some View {
        if !settingsManager.settings.hasCompletedOnboarding {
            // Simplified view when onboarding is not complete
            onboardingIncompleteView
        } else if let timerEngine = timerEngine {
            // Full view when onboarding is complete and timers are running
            fullMenuBarView(timerEngine: timerEngine)
        } else {
            // Fallback view
            EmptyView()
        }
    }

    private var onboardingIncompleteView: some View {
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

            // Message
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome to Gaze!")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 16)

                Text("Complete the onboarding to start using Gaze!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.bottom, 16)
            }

            Divider()

            // Complete Onboarding Button
            VStack(spacing: 4) {
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
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("CloseMenuBarPopover"))
        ) { _ in
            dismiss()
        }
    }

    private func fullMenuBarView(timerEngine: TimerEngine) -> some View {
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

                // Show regular timers with individual pause/resume controls
                ForEach(Array(timerEngine.timerStates.keys), id: \.self) { timerType in
                    if let state = timerEngine.timerStates[timerType] {
                        TimerStatusRowWithIndividualControls(
                            variant: .builtIn(timerType),
                            timerEngine: timerEngine,
                            onSkip: {
                                timerEngine.skipNext(type: timerType)
                            },
                            onDevTrigger: {
                                timerEngine.triggerReminder(for: timerType)
                            },
                            onTogglePause: { isPaused in
                                if isPaused {
                                    timerEngine.pauseTimer(type: timerType)
                                } else {
                                    timerEngine.resumeTimer(type: timerType)
                                }
                            },
                            onTap: {
                                onOpenSettingsTab(timerType.tabIndex)
                            }
                        )
                    }
                }

                // Show user timers with individual pause/resume controls
                ForEach(settingsManager.settings.userTimers.filter { $0.enabled }, id: \.id) {
                    userTimer in
                    TimerStatusRowWithIndividualControls(
                        variant: .user(userTimer),
                        timerEngine: timerEngine,
                        onSkip: {
                            //TODO
                        },
                        onTogglePause: { isPaused in
                            if isPaused {
                                timerEngine.pauseUserTimer(userTimer.id)
                            } else {
                                timerEngine.resumeUserTimer(userTimer.id)
                            }
                        },
                        onTap: {
                            onOpenSettingsTab(3)  // Switch to User Timers tab
                        }
                    )
                }
            }
            .padding(.bottom, 8)

            Divider()

            // Controls
            VStack(spacing: 4) {
                Button(action: {
                    if isAllPaused(timerEngine: timerEngine) {
                        timerEngine.resume()
                    } else {
                        timerEngine.pause()
                    }
                }) {
                    HStack {
                        Image(
                            systemName: isAllPaused(timerEngine: timerEngine)
                                ? "play.circle" : "pause.circle")
                        Text(
                            isAllPaused(timerEngine: timerEngine)
                                ? "Resume All Timers" : "Pause All Timers")
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
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("CloseMenuBarPopover"))
        ) { _ in
            dismiss()
        }
    }

    private func isAllPaused(timerEngine: TimerEngine) -> Bool {
        // Check if all timers are paused
        let activeStates = timerEngine.timerStates.values.filter { $0.isActive }
        return !activeStates.isEmpty && activeStates.allSatisfy { $0.isPaused }
    }
}

struct TimerStatusRowWithIndividualControls: View {
    enum TimerVariant {
        case builtIn(TimerType)
        case user(UserTimer)

        var displayName: String {
            switch self {
            case .builtIn(let type): return type.displayName
            case .user(let timer): return timer.title
            }
        }

        var iconName: String {
            switch self {
            case .builtIn(let type): return type.iconName
            case .user: return "clock.fill"
            }
        }

        var color: Color {
            switch self {
            case .builtIn(_):
                return .accentColor

            case .user(let timer): return timer.color
            }
        }

        var tooltipText: String {
            switch self {
            case .builtIn(let type): return type.tooltipText
            case .user(let timer):
                let typeText = timer.type == .subtle ? "Subtle" : "Overlay"
                let durationText = "\(timer.timeOnScreenSeconds)s on screen"
                let statusText = timer.enabled ? "" : " (Disabled)"
                return "\(typeText) timer - \(durationText)\(statusText)"
            }
        }
    }

    let variant: TimerVariant
    @ObservedObject var timerEngine: TimerEngine
    var onSkip: () -> Void
    var onDevTrigger: (() -> Void)? = nil
    var onTogglePause: (Bool) -> Void
    var onTap: (() -> Void)? = nil
    @State private var isHoveredSkip = false
    @State private var isHoveredDevTrigger = false
    @State private var isHoveredBody = false
    @State private var isHoveredPauseButton = false

    private var state: TimerState? {
        switch variant {
        case .builtIn(let type):
            return timerEngine.timerStates[type]
        case .user(let timer):
            return timerEngine.userTimerStatesReadOnly[timer.id]
        }
    }

    private var isPaused: Bool {
        switch variant {
        case .builtIn:
            return state?.isPaused ?? false
        case .user(let timer):
            return !timer.enabled
        }
    }

    var body: some View {
        HStack {
            HStack {
                // Show color indicator circle for user timers
                if case .user(let timer) = variant {
                    Circle()
                        .fill(isHoveredBody ? .white : timer.color)
                        .frame(width: 8, height: 8)
                }

                Image(systemName: variant.iconName)
                    .foregroundColor(isHoveredBody ? .white : variant.color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(variant.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isHoveredBody ? .white : .primary)
                        .lineLimit(1)

                    if let state = state {
                        Text(timeRemaining(state))
                            .font(.caption)
                            .foregroundColor(isHoveredBody ? .white.opacity(0.8) : .secondary)
                            .monospacedDigit()
                    }
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
                            .foregroundColor(isHoveredDevTrigger ? .white : .yellow)
                            .padding(6)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffectIfAvailable(
                        isHoveredDevTrigger
                            ? GlassStyle.regular.tint(.yellow) : GlassStyle.regular,
                        in: .circle
                    )
                    .help("Trigger \(variant.displayName) reminder now (dev)")
                    .onHover { hovering in
                        isHoveredDevTrigger = hovering
                    }
                }
            #endif

            // Individual pause/resume button
            Button(action: {
                onTogglePause(!isPaused)
            }) {
                Image(
                    systemName: isPaused ? "play.circle" : "pause.circle"
                )
                .font(.caption)
                .foregroundColor(isHoveredPauseButton ? .white : .accentColor)
                .padding(6)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(
                isHoveredPauseButton
                    ? GlassStyle.regular.tint(.accentColor) : GlassStyle.regular,
                in: .circle
            )
            .help(
                isPaused
                    ? "Resume \(variant.displayName)" : "Pause \(variant.displayName)"
            )
            .onHover { hovering in
                isHoveredPauseButton = hovering
            }

            Button(action: onSkip) {
                Image(systemName: "forward.fill")
                    .font(.caption)
                    .foregroundColor(isHoveredSkip ? .white : .accentColor)
                    .padding(6)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(
                isHoveredSkip
                    ? GlassStyle.regular.tint(.accentColor) : GlassStyle.regular,
                in: .circle
            )
            .help("Skip to next \(variant.displayName) reminder")
            .onHover { hovering in
                isHoveredSkip = hovering
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffectIfAvailable(
            isHoveredBody
                ? GlassStyle.regular.tint(variant.color)
                : GlassStyle.regular,
            in: .rect(cornerRadius: 6)
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHoveredBody = hovering
        }
        .help(variant.tooltipText)
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
