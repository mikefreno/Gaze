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

    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 60))
                .foregroundColor(.purple)

            Text("Custom Timers")
                .font(.system(size: 28, weight: .bold))

            Text("Create your own reminder schedules")
                .font(.title3)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "info.circle")
                    .foregroundColor(.white)
                Text("Add up to 3 custom timers with your own intervals and messages")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
            .glassEffect(.regular.tint(.purple), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Timers (\(userTimers.count)/3)")
                        .font(.headline)
                    Spacer()
                    if userTimers.count < 3 {
                        Button(action: {
                            showingAddTimer = true
                        }) {
                            Label("Add Timer", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if userTimers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No custom timers yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Click 'Add Timer' to create your first custom reminder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(userTimers) { timer in
                                UserTimerRow(
                                    timer: timer,
                                    onEdit: {
                                        editingTimer = timer
                                    },
                                    onDelete: {
                                        if let index = userTimers.firstIndex(where: {
                                            $0.id == timer.id
                                        }) {
                                            userTimers.remove(at: index)
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
        .sheet(isPresented: $showingAddTimer) {
            UserTimerEditSheet(
                timer: nil,
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
    let timer: UserTimer
    var onEdit: () -> Void
    var onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: timer.type == .subtle ? "eye.circle" : "rectangle.on.rectangle")
                .foregroundColor(.purple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(timer.message ?? "Custom Timer")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(timer.type.displayName) • \(timer.timeOnScreenSeconds)s on screen")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "trash.circle")
                        .font(.title3)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
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
    var onSave: (UserTimer) -> Void
    var onCancel: () -> Void

    @State private var message: String
    @State private var type: UserTimerType
    @State private var timeOnScreen: Int

    init(
        timer: UserTimer?,
        onSave: @escaping (UserTimer) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.timer = timer
        self.onSave = onSave
        self.onCancel = onCancel

        _message = State(initialValue: timer?.message ?? "")
        _type = State(initialValue: timer?.type ?? .subtle)
        _timeOnScreen = State(initialValue: timer?.timeOnScreenSeconds ?? 30)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(timer == nil ? "Add Custom Timer" : "Edit Custom Timer")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Type")
                        .font(.headline)

                    Picker("Display Type", selection: $type) {
                        ForEach(UserTimerType.allCases) { timerType in
                            Text(timerType.displayName).tag(timerType)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(
                        type == .subtle
                            ? "Small reminder in corner of screen"
                            : "Full screen reminder with animation"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Duration on Screen")
                        .font(.headline)
                    HStack {
                        Slider(
                            value: Binding(
                                get: { Double(timeOnScreen) },
                                set: { timeOnScreen = Int($0) }
                            ),
                            in: 5...120,
                            step: 5
                        )
                        Text("\(timeOnScreen)s")
                            .frame(width: 50, alignment: .trailing)
                            .monospacedDigit()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Message (Optional)")
                        .font(.headline)
                    TextField("Enter custom reminder message", text: $message)
                        .textFieldStyle(.roundedBorder)
                    Text("Leave blank to show a default timer notification")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .glassEffect(.regular, in: .rect(cornerRadius: 12))

            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)

                Button(timer == nil ? "Add" : "Save") {
                    let newTimer = UserTimer(
                        id: timer?.id ?? UUID().uuidString,
                        type: type,
                        timeOnScreenSeconds: timeOnScreen,
                        message: message.isEmpty ? nil : message
                    )
                    onSave(newTimer)
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

#Preview("User Timers - Empty") {
    UserTimersView(userTimers: .constant([]))
}

#Preview("User Timers - With Timers") {
    UserTimersView(
        userTimers: .constant([
            UserTimer(
                id: "1", type: .subtle, timeOnScreenSeconds: 30, message: "Take a break"),
            UserTimer(
                id: "2", type: .overlay, timeOnScreenSeconds: 60,
                message: "Stretch your legs"),
        ])
    )
}
