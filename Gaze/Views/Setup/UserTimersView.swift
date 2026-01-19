//
//  UserTimersView.swift
//  Gaze
//
//  Created by Mike Freno on 1/9/26.
//

import SwiftUI

struct UserTimersView: View {
    @Binding var userTimers: [UserTimer]
    @State private var editingTimer: UserTimer?
    @State private var showingAddTimer = false
    @Environment(\.isCompactLayout) private var isCompact

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: isCompact ? 10 : 16) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: isCompact ? AdaptiveLayout.Font.heroIconSmall : AdaptiveLayout.Font.heroIcon))
                    .foregroundStyle(.purple)
                Text("Custom Timers")
                    .font(.system(size: isCompact ? AdaptiveLayout.Font.heroTitleSmall : AdaptiveLayout.Font.heroTitle, weight: .bold))
            }
            .padding(.top, isCompact ? 12 : 20)
            .padding(.bottom, isCompact ? 16 : 30)

            Spacer()
            VStack(spacing: isCompact ? 16 : 30) {
                Text("Create your own reminder schedules")
                    .font(isCompact ? .subheadline : .title3)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.white)
                    Text("Add up to 3 custom timers with your own intervals and messages")
                        .font(isCompact ? .subheadline : .headline)
                        .foregroundStyle(.white)
                }
                .padding(isCompact ? 10 : 16)
                .glassEffectIfAvailable(
                    GlassStyle.regular.tint(.purple), in: .rect(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 12) {
                    /*#if APPSTORE || DEBUG*/
                    // we will add these back in when payment method is established - and checked
                    // for
                    HStack {
                        Text("Active Timers (\(userTimers.count)/3)")
                            .font(isCompact ? .subheadline : .headline)
                        Spacer()
                        if userTimers.count < 3 {
                            Button(action: {
                                showingAddTimer = true
                            }) {
                                Label("Add Timer", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(isCompact ? .small : .regular)
                        }
                    }
                    /*#else*/
                    /*Text("Custom Timers avilable in App Store version only")*/
                    /*#endif*/

                    if userTimers.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: isCompact ? 28 : 40))
                                .foregroundStyle(.secondary)
                            Text("No custom timers yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Click 'Add Timer' to create your first custom reminder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(isCompact ? 24 : 40)
                    } else {
                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(Array(userTimers.enumerated()), id: \.element.id) {
                                    index, timer in
                                    UserTimerRow(
                                        timer: $userTimers[index],
                                        isCompact: isCompact,
                                        onEdit: {
                                            editingTimer = timer
                                        },
                                        onDelete: {
                                            if let idx = userTimers.firstIndex(where: {
                                                $0.id == timer.id
                                            }) {
                                                userTimers.remove(at: idx)
                                            }
                                        }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: isCompact ? 150 : 200)
                    }
                }
                .padding(isCompact ? 10 : 16)
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
        .sheet(isPresented: $showingAddTimer) {
            UserTimerEditSheet(
                timer: nil,
                existingTimersCount: userTimers.count,
                onSave: { newTimer in
                    userTimers.append(newTimer)
                    showingAddTimer = false
                },
                onCancel: {
                    showingAddTimer = false
                }
            )
        }
        .sheet(item: $editingTimer) { timer in
            UserTimerEditSheet(
                timer: timer,
                existingTimersCount: userTimers.count,
                onSave: { updatedTimer in
                    if let index = userTimers.firstIndex(where: { $0.id == timer.id }) {
                        userTimers[index] = updatedTimer
                    }
                    editingTimer = nil
                },
                onCancel: {
                    editingTimer = nil
                }
            )
        }
    }
}

struct UserTimerRow: View {
    @Binding var timer: UserTimer
    var isCompact: Bool = false
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var isHovered = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        HStack(spacing: isCompact ? 8 : 12) {
            Circle()
                .fill(timer.color)
                .frame(width: isCompact ? 10 : 12, height: isCompact ? 10 : 12)

            Image(systemName: timer.type == .subtle ? "eye.circle" : "rectangle.on.rectangle")
                .foregroundStyle(timer.color)
                .frame(width: isCompact ? 20 : 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(timer.title)
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(
                    "\(timer.type.displayName) • \(timer.timeOnScreenSeconds)s on screen • \(timer.intervalMinutes) min interval"
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            HStack(spacing: isCompact ? 4 : 8) {
                Toggle("", isOn: $timer.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)

                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(isCompact ? .subheadline : .title3)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)

                Button(action: { showingDeleteConfirmation = true }) {
                    Image(systemName: "trash.circle.fill")
                        .font(isCompact ? .subheadline : .title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .confirmationDialog("Delete Timer", isPresented: $showingDeleteConfirmation) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(
                        "Are you sure you want to delete this timer? This action cannot be undone.")
                }
            }
        }
        .padding(isCompact ? 8 : 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(isHovered ? 0.1 : 0.05))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct UserTimerEditSheet: View {
    let timer: UserTimer?
    let existingTimersCount: Int
    var onSave: (UserTimer) -> Void
    var onCancel: () -> Void

    @State private var title: String
    @State private var message: String
    @State private var type: UserTimerType
    @State private var timeOnScreen: Int
    @State private var intervalMinutes: Int
    @State private var selectedColorHex: String

    init(
        timer: UserTimer?,
        existingTimersCount: Int = 0,
        onSave: @escaping (UserTimer) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.timer = timer
        self.existingTimersCount = existingTimersCount
        self.onSave = onSave
        self.onCancel = onCancel

        _title = State(
            initialValue: timer?.title ?? UserTimer.generateTitle(for: existingTimersCount))
        _message = State(initialValue: timer?.message ?? "")
        let timerType = timer?.type ?? .subtle
        _type = State(initialValue: timerType)
        // Subtle timers always use 3 seconds (not configurable)
        // Overlay timers default to 10 seconds (configurable)
        _timeOnScreen = State(
            initialValue: timer?.timeOnScreenSeconds ?? (timerType == .subtle ? 3 : 10))
        _intervalMinutes = State(initialValue: timer?.intervalMinutes ?? 15)
        _selectedColorHex = State(
            initialValue: timer?.colorHex
                ?? UserTimer.defaultColors[existingTimersCount % UserTimer.defaultColors.count])
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(timer == nil ? "Add Custom Timer" : "Edit Custom Timer")
                .font(.title3)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Timer title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    Text("Example: \"Stretch Break\", \"Eye Rest\", \"Water Break\"")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Color")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8),
                        spacing: 8
                    ) {
                        ForEach(UserTimer.defaultColors, id: \.self) { colorHex in
                            Button(action: {
                                selectedColorHex = colorHex
                            }) {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .purple)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(
                                                Color.white,
                                                lineWidth: selectedColorHex == colorHex ? 2 : 0)
                                    )
                                    .shadow(
                                        color: selectedColorHex == colorHex ? .accentColor : .clear,
                                        radius: 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Picker("Display Type", selection: $type) {
                        ForEach(UserTimerType.allCases) { timerType in
                            Text(timerType.displayName).tag(timerType)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, newType in
                        if newType == .subtle {
                            timeOnScreen = 3
                        } else if timeOnScreen == 3 {
                            timeOnScreen = 10
                        }
                    }

                    Text(
                        type == .subtle
                            ? "Small reminder at top of screen"
                            : "Full screen reminder with animation"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if type == .overlay {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Duration on Screen")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        HStack {
                            Slider(
                                value: Binding(
                                    get: { Double(timeOnScreen) },
                                    set: { timeOnScreen = Int($0) }
                                ),
                                in: 5...30,
                                step: 1
                            )
                            Text("\(timeOnScreen)s")
                                .frame(width: 40, alignment: .trailing)
                                .monospacedDigit()
                                .font(.caption)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Interval")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(intervalMinutes) },
                                set: { intervalMinutes = Int($0) }
                            ),
                            in: 1...120,
                            step: 1
                        )
                        Text("\(intervalMinutes) min")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                            .font(.caption)
                    }
                    Text("How often this reminder will appear (in minutes)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Message (Optional)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Enter custom reminder message", text: $message)
                        .textFieldStyle(.roundedBorder)
                    Text("Leave blank to show a default timer notification")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)

                Button(timer == nil ? "Add" : "Save") {
                    let newTimer = UserTimer(
                        id: timer?.id ?? UUID().uuidString,
                        title: title,
                        type: type,
                        timeOnScreenSeconds: timeOnScreen,
                        intervalMinutes: intervalMinutes,
                        message: message.isEmpty ? nil : message,
                        colorHex: selectedColorHex,
                        enabled: timer?.enabled ?? true
                    )
                    onSave(newTimer)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(minWidth: 360, idealWidth: 420, maxWidth: 480)
    }
}

#Preview("User Timers - Empty") {
    UserTimersView(userTimers: .constant([]))
}

#Preview("User Timers - With Timers") {
    UserTimersView(
        userTimers: .constant([
            UserTimer(
                id: "1", title: "User Reminder 1", type: .subtle, timeOnScreenSeconds: 30,
                intervalMinutes: 15, message: "Take a break", colorHex: "9B59B6"),
            UserTimer(
                id: "2", title: "User Reminder 2", type: .overlay, timeOnScreenSeconds: 60,
                intervalMinutes: 30, message: "Stretch your legs", colorHex: "3498DB"),
        ])
    )
}
