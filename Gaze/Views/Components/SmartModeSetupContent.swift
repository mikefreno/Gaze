//
//  SmartModeSetupContent.swift
//  Gaze
//
//  Created by Mike Freno on 1/30/26.
//

import SwiftUI

struct SmartModeSetupContent: View {
    @Bindable var settingsManager: SettingsManager
    @State private var permissionManager = ScreenCapturePermissionManager.shared
    let presentation: SetupPresentation

    private var iconSize: CGFloat {
        presentation.isCard ? AdaptiveLayout.Font.cardIconSmall : AdaptiveLayout.Font.cardIcon
    }

    private var sectionCornerRadius: CGFloat {
        presentation.isCard ? 10 : 12
    }

    private var sectionPadding: CGFloat {
        presentation.isCard ? 10 : 16
    }

    private var sectionSpacing: CGFloat {
        presentation.isCard ? 8 : 12
    }

    var body: some View {
        VStack(spacing: presentation.isCard ? 10 : 24) {
            if presentation.isCard {
                Image(systemName: "brain.fill")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.purple)

                Text("Smart Mode")
                    .font(.title2)
                    .fontWeight(.bold)
            }

            Text("Automatically manage timers based on your activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if presentation.isCard {
                Spacer(minLength: 0)
            }

            VStack(spacing: sectionSpacing) {
                fullscreenSection
                idleSection
                #if DEBUG
                    usageTrackingSection
                #endif
            }
            .frame(maxWidth: presentation.isCard ? .infinity : 600)

            if presentation.isCard {
                Spacer(minLength: 0)
            }
        }
    }

    private var fullscreenSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .foregroundStyle(.blue)
                        Text("Auto-pause on Fullscreen")
                            .font(presentation.isCard ? .subheadline : .headline)
                    }
                    Text("Timers will automatically pause when you enter fullscreen mode (videos, games, presentations)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settingsManager.settings.smartMode.autoPauseOnFullscreen)
                    .labelsHidden()
                    .controlSize(presentation.isCard ? .small : .regular)
                    .onChange(of: settingsManager.settings.smartMode.autoPauseOnFullscreen) { _, newValue in
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
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
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
                .controlSize(presentation.isCard ? .small : .regular)

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
                            .font(presentation.isCard ? .subheadline : .headline)
                    }
                    Text("Timers will pause when you're inactive for more than the threshold below")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settingsManager.settings.smartMode.autoPauseOnIdle)
                    .labelsHidden()
                    .controlSize(presentation.isCard ? .small : .regular)
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
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
    }

    private var usageTrackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.green)
                        Text("Track Usage Statistics")
                            .font(presentation.isCard ? .subheadline : .headline)
                    }
                    Text("Monitor active and idle time, with automatic reset after the specified duration")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: $settingsManager.settings.smartMode.trackUsage)
                    .labelsHidden()
                    .controlSize(presentation.isCard ? .small : .regular)
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
        .padding(sectionPadding)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: sectionCornerRadius))
    }
}
