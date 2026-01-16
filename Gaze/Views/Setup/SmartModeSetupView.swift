//
//  SmartModeSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import SwiftUI

struct SmartModeSetupView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var permissionManager = ScreenCapturePermissionManager.shared

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "brain.fill", title: "Smart Mode", color: .purple)

            Text("Automatically manage timers based on your activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 30)

            Spacer()

            VStack(spacing: 24) {
                fullscreenSection
                idleSection
                usageTrackingSection
            }
            .frame(maxWidth: 600)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
    }

    private var fullscreenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundStyle(.blue)
                        Text("Auto-pause on Fullscreen")
                            .font(.headline)
                    }
                    Text(
                        "Timers will automatically pause when you enter fullscreen mode (videos, games, presentations)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settingsManager.settings.smartMode.autoPauseOnFullscreen)
                    .labelsHidden()
                    .onChange(of: settingsManager.settings.smartMode.autoPauseOnFullscreen) {
                        _, newValue in
                        if newValue {
                            permissionManager.requestAuthorizationIfNeeded()
                        }
                    }
            }

            if settingsManager.settings.smartMode.autoPauseOnFullscreen,
                permissionManager.authorizationStatus != .authorized
            {
                permissionWarningView
            }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 8))
    }

    private var permissionWarningView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                permissionManager.authorizationStatus == .denied
                    ? "Screen Recording permission required"
                    : "Grant Screen Recording access",
                systemImage: "exclamationmark.shield"
            )
            .foregroundStyle(.orange)

            Text("macOS requires Screen Recording permission to detect other apps in fullscreen.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Grant Access") {
                    permissionManager.requestAuthorizationIfNeeded()
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(.bordered)

                Button("Open Settings") {
                    permissionManager.openSystemSettings()
                }
                .buttonStyle(.borderless)
            }
            .font(.caption)
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    private var idleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "moon.zzz.fill")
                            .foregroundStyle(.indigo)
                        Text("Auto-pause on Idle")
                            .font(.headline)
                    }
                    Text("Timers will pause when you're inactive for more than the threshold below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settingsManager.settings.smartMode.autoPauseOnIdle)
                    .labelsHidden()
            }

            if settingsManager.settings.smartMode.autoPauseOnIdle {
                ThresholdSlider(
                    label: "Idle Threshold:",
                    value: $settingsManager.settings.smartMode.idleThresholdMinutes,
                    range: 1...30,
                    unit: "min"
                )
            }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 8))
    }

    private var usageTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.green)
                        Text("Track Usage Statistics")
                            .font(.headline)
                    }
                    Text(
                        "Monitor active and idle time, with automatic reset after the specified duration"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settingsManager.settings.smartMode.trackUsage)
                    .labelsHidden()
            }

            if settingsManager.settings.smartMode.trackUsage {
                ThresholdSlider(
                    label: "Reset After:",
                    value: $settingsManager.settings.smartMode.usageResetAfterMinutes,
                    range: 15...240,
                    step: 15,
                    unit: "min"
                )
            }
        }
        .padding()
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 8))
    }
}

struct ThresholdSlider: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text("\(value) \(unit)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
        }
        .padding(.top, 8)
    }
}

#Preview {
    SmartModeSetupView(settingsManager: SettingsManager.shared)
}
