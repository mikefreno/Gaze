//
//  MenuBarContentView.swift
//  Gaze
//
//  Created by Mike Freno on 1/7/26.
//

import SwiftUI

struct MenuBarContentWrapper: View {
    @ObservedObject var appDelegate: AppDelegate
    @Bindable var settingsManager: SettingsManager
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

struct MenuBarHoverButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffectIfAvailable(
                isHovered
                    ? GlassStyle.regular.tint(.accentColor).interactive()
                    : GlassStyle.regular,
                in: .rect(cornerRadius: 6),
                colorScheme: colorScheme
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isHovered)
    }
}

struct MenuBarContentView: View {
    var timerEngine: TimerEngine?
    @Bindable var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    var onQuit: () -> Void
    var onOpenSettings: () -> Void
    var onOpenSettingsTab: (Int) -> Void
    var onOpenOnboarding: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if settingsManager.settings.hasCompletedOnboarding {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Active Timers")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 8)

                    ForEach(
                        timerEngine.map { getSortedTimerIdentifiers(timerEngine: $0) } ?? [],
                        id: \.self
                    ) {
                        identifier in
                        if let engine = timerEngine, engine.timerStates[identifier] != nil {
                            TimerStatusRowWithIndividualControls(
                                identifier: identifier,
                                timerEngine: engine,
                                settingsManager: settingsManager,
                                onSkip: {
                                    engine.skipNext(identifier: identifier)
                                },
                                onDevTrigger: {
                                    engine.triggerReminder(for: identifier)
                                },
                                onTogglePause: { isPaused in
                                    if isPaused {
                                        engine.pauseTimer(identifier: identifier)
                                    } else {
                                        engine.resumeTimer(identifier: identifier)
                                    }
                                },
                                onTap: {
                                    switch identifier {
                                    case .builtIn(let type):
                                        onOpenSettingsTab(type.tabIndex)
                                    case .user:
                                        onOpenSettingsTab(4)
                                    }
                                }
                            )
                        }
                    }
                }
                .padding(.bottom, 8)

                Divider()

                // Controls
                VStack(spacing: 4) {
                    Button(action: {
                        if let engine = timerEngine {
                            if isAllPaused(timerEngine: engine) {
                                engine.resume()
                            } else {
                                engine.pause()
                            }
                        }
                    }) {
                        HStack {
                            Image(
                                systemName: timerEngine.map { isAllPaused(timerEngine: $0) }
                                    ?? false
                                    ? "play.circle" : "pause.circle")
                            Text(
                                timerEngine.map { isAllPaused(timerEngine: $0) } ?? false
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
            } else {
                IncompleteOnboardingView(onOpenOnboarding: onOpenOnboarding)
            }

            QuitRow(onQuit: onQuit)

        }
        .frame(width: 300)
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("CloseMenuBarPopover"))
        ) { _ in
            dismiss()
        }
    }

    private func isAllPaused(timerEngine: TimerEngine?) -> Bool {
        // Check if all timers are paused
        guard let engine = timerEngine else { return false }
        let activeStates = engine.timerStates.values.filter { $0.isActive }
        return !activeStates.isEmpty && activeStates.allSatisfy { $0.isPaused }
    }

    private func getSortedTimerIdentifiers(timerEngine: TimerEngine?) -> [TimerIdentifier] {
        guard let engine = timerEngine else { return [] }
        return engine.timerStates.keys.sorted { id1, id2 in
            // Sort built-in timers before user timers
            switch (id1, id2) {
            case (.builtIn(let t1), .builtIn(let t2)):
                return t1.tabIndex < t2.tabIndex
            case (.builtIn, .user):
                return true
            case (.user, .builtIn):
                return false
            case (.user(let id1), .user(let id2)):
                return id1 < id2
            }
        }
    }
}
struct IncompleteOnboardingView: View {
    @State private var isHovering = false

    let onOpenOnboarding: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Button(action: {
                onOpenOnboarding()
            }) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(isHovering ? .white : .accentColor)
                    Text("Complete Onboarding")
                        .foregroundStyle(isHovering ? .white : .primary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .buttonStyle(MenuBarHoverButtonStyle())
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
    }
}
struct QuitRow: View {
    @State private var isHovering = false

    let onQuit: () -> Void

    var body: some View {
        HStack {
            Button(action: onQuit) {
                HStack {
                    Image(systemName: "power")
                        .foregroundStyle(isHovering ? .white : .red)
                    Text("Quit Gaze")
                        .foregroundStyle(isHovering ? .white : .primary)
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .buttonStyle(MenuBarHoverButtonStyle())
            .padding(.vertical, 8)
            Spacer()
            Text(
                "v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0")"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

struct TimerStatusRowWithIndividualControls: View {
    let identifier: TimerIdentifier
    @ObservedObject var timerEngine: TimerEngine
    @Bindable var settingsManager: SettingsManager
    var onSkip: () -> Void
    var onDevTrigger: (() -> Void)? = nil
    var onTogglePause: (Bool) -> Void
    var onTap: (() -> Void)? = nil
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHoveredSkip = false
    @State private var isHoveredDevTrigger = false
    @State private var isHoveredBody = false
    @State private var isHoveredPauseButton = false

    private var state: TimerState? {
        return timerEngine.timerStates[identifier]
    }

    private var isPaused: Bool {
        return state?.isPaused ?? false
    }

    private var displayName: String {
        switch identifier {
        case .builtIn(let type):
            return type.displayName
        case .user(let id):
            return settingsManager.settings.userTimers.first(where: { $0.id == id })?.title
                ?? "User Timer"
        }
    }

    private var iconName: String {
        switch identifier {
        case .builtIn(let type):
            return type.iconName
        case .user:
            return "clock.fill"
        }
    }

    private var color: Color {
        switch identifier {
        case .builtIn(let type):
            switch type {
            case .lookAway: return .accentColor
            case .blink: return .green
            case .posture: return .orange
            }
        case .user(let id):
            return settingsManager.settings.userTimers.first(where: { $0.id == id })?.color
                ?? .purple
        }
    }

    private var tooltipText: String {
        switch identifier {
        case .builtIn(let type):
            return type.tooltipText
        case .user(let id):
            guard let timer = settingsManager.settings.userTimers.first(where: { $0.id == id })
            else {
                return "User Timer"
            }
            let typeText = timer.type == .subtle ? "Subtle" : "Overlay"
            let durationText = "\(timer.timeOnScreenSeconds)s on screen"
            let statusText = timer.enabled ? "" : " (Disabled)"
            return "\(typeText) timer - \(durationText)\(statusText)"
        }
    }

    private var userTimer: UserTimer? {
        if case .user(let id) = identifier {
            return settingsManager.settings.userTimers.first(where: { $0.id == id })
        }
        return nil
    }

    var body: some View {
        HStack {
            HStack {
                // Show color indicator circle for user timers
                if let timer = userTimer {
                    Circle()
                        .fill(isHoveredBody ? .white : timer.color)
                        .frame(width: 8, height: 8)
                }

                Image(systemName: iconName)
                    .foregroundStyle(isHoveredBody ? .white : color)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(isHoveredBody ? .white : .primary)
                        .lineLimit(1)

                    if let state = state {
                        Text(state.remainingSeconds.asTimerDuration)
                            .font(.caption)
                            .foregroundStyle(isHoveredBody ? .white.opacity(0.8) : .secondary)
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
                            .foregroundStyle(isHoveredDevTrigger ? .white : .yellow)
                            .padding(6)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .glassEffectIfAvailable(
                        isHoveredDevTrigger
                            ? GlassStyle.regular.tint(.yellow) : GlassStyle.regular,
                        in: .circle,
                        colorScheme: colorScheme
                    )
                    .help("Trigger \(displayName) reminder now (dev)")
                    .accessibilityIdentifier(
                        "trigger_\(displayName.replacingOccurrences(of: " ", with: "_"))"
                    )
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
                .foregroundStyle(isHoveredPauseButton ? .white : .accentColor)
                .padding(6)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(
                isHoveredPauseButton
                    ? GlassStyle.regular.tint(.accentColor) : GlassStyle.regular,
                in: .circle,
                colorScheme: colorScheme
            )
            .help(
                isPaused
                    ? "Resume \(displayName)" : "Pause \(displayName)"
            )
            .onHover { hovering in
                isHoveredPauseButton = hovering
            }

            Button(action: onSkip) {
                Image(systemName: "forward.fill")
                    .font(.caption)
                    .foregroundStyle(isHoveredSkip ? .white : .accentColor)
                    .padding(6)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(
                isHoveredSkip
                    ? GlassStyle.regular.tint(.accentColor) : GlassStyle.regular,
                in: .circle,
                colorScheme: colorScheme
            )
            .help("Skip to next \(displayName) reminder")
            .onHover { hovering in
                isHoveredSkip = hovering
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .glassEffectIfAvailable(
            isHoveredBody
                ? GlassStyle.regular.tint(.accentColor)
                : GlassStyle.regular,
            in: .rect(cornerRadius: 6),
            colorScheme: colorScheme
        )
        .padding(.horizontal, 8)
        .onHover { hovering in
            isHoveredBody = hovering
        }
        .help(tooltipText)
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
