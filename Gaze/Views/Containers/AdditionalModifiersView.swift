//
//  AdditionalModifiersView.swift
//  Gaze
//
//  Created by Mike Freno on 1/18/26.
//

import SwiftUI

struct AdditionalModifiersView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var frontCardIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @Environment(\.isCompactLayout) private var isCompact

    private var backCardOffset: CGFloat { isCompact ? 20 : AdaptiveLayout.Card.backOffset }
    private var backCardScale: CGFloat { AdaptiveLayout.Card.backScale }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 60  // Account for padding
            let availableHeight = geometry.size.height - 160  // Account for header and nav

            let cardWidth = min(
                max(availableWidth * 0.85, AdaptiveLayout.Card.minWidth),
                AdaptiveLayout.Card.maxWidth
            )
            let cardHeight = min(
                max(availableHeight * 0.75, AdaptiveLayout.Card.minHeight),
                AdaptiveLayout.Card.maxHeight
            )

            VStack(spacing: 0) {
                SetupHeader(
                    icon: "slider.horizontal.3", title: "Additional Options", color: .purple)

                Text("Optional features to enhance your experience")
                    .font(isCompact ? .subheadline : .title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                #if !ENFORCE_READY
                    Text("More to come soon")
                        .font(isCompact ? .subheadline : .title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                #endif

                Spacer()

                ZStack {
                    #if ENFORCE_READY
                        cardView(for: 0, width: cardWidth, height: cardHeight)
                            .zIndex(zIndex(for: 0))
                            .scaleEffect(scale(for: 0))
                            .offset(x: xOffset(for: 0), y: yOffset(for: 0))
                    #endif
                    cardView(for: 1, width: cardWidth, height: cardHeight)
                        .zIndex(zIndex(for: 1))
                        .scaleEffect(scale(for: 1))
                        .offset(x: xOffset(for: 1), y: yOffset(for: 1))
                }
                .padding(isCompact ? 12 : 20)
                .gesture(dragGesture)

                Spacer()

                #if ENFORCE_READY
                    HStack(spacing: isCompact ? 12 : 20) {
                        Button(action: { swapCards() }) {
                            Image(systemName: "chevron.left")
                                .font(isCompact ? .body : .title2)
                                .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffectIfAvailable(
                            GlassStyle.regular.interactive(), in: .rect(cornerRadius: 10)
                        )
                        .opacity(frontCardIndex == 0 ? 0.3 : 1.0)
                        .disabled(frontCardIndex == 0)

                        // Page indicators with labels
                        HStack(spacing: isCompact ? 10 : 16) {
                            cardIndicator(index: 0, icon: "video.fill", label: "Enforce")
                            cardIndicator(index: 1, icon: "brain.fill", label: "Smart")
                        }.padding(.all, 20)

                        Button(action: { swapCards() }) {
                            Image(systemName: "chevron.right")
                                .font(isCompact ? .body : .title2)
                                .frame(width: isCompact ? 36 : 44, height: isCompact ? 36 : 44)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffectIfAvailable(
                            GlassStyle.regular.interactive(), in: .rect(cornerRadius: 10)
                        )
                        .opacity(frontCardIndex == 1 ? 0.3 : 1.0)
                        .disabled(frontCardIndex == 1)
                    }
                    .padding(.bottom, isCompact ? 6 : 10)
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    // MARK: - Card Indicator

    @ViewBuilder
    private func cardIndicator(index: Int, icon: String, label: String) -> some View {
        Button(action: {
            if index != frontCardIndex {
                swapCards()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, isCompact ? 5 : 6)
            .foregroundStyle(index == frontCardIndex ? .primary : .secondary)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(
            index == frontCardIndex
                ? GlassStyle.regular.tint(Color.accentColor.opacity(0.3))
                : GlassStyle.regular,
            in: .capsule
        )
    }

    // MARK: - Card Transform Calculations

    private func zIndex(for cardIndex: Int) -> Double {
        let isFront = cardIndex == frontCardIndex
        let dragProgress = abs(dragOffset) / 150

        if isDragging && dragProgress > 0.3 {
            return isFront ? 0 : 1
        }
        return isFront ? 1 : 0
    }

    private func scale(for cardIndex: Int) -> CGFloat {
        let isFront = cardIndex == frontCardIndex
        let dragProgress = min(abs(dragOffset) / 150, 1.0)

        if isFront {
            return 1.0 - (dragProgress * (1.0 - backCardScale))
        } else {
            return backCardScale + (dragProgress * (1.0 - backCardScale))
        }
    }

    private func xOffset(for cardIndex: Int) -> CGFloat {
        let isFront = cardIndex == frontCardIndex
        let dragProgress = min(abs(dragOffset) / 150, 1.0)
        let backPeekX = backCardOffset

        if isFront {
            return dragOffset + (dragProgress * backPeekX * (dragOffset > 0 ? -1 : 1))
        } else {
            return backPeekX * (1.0 - dragProgress)
        }
    }

    private func yOffset(for cardIndex: Int) -> CGFloat {
        let isFront = cardIndex == frontCardIndex
        let dragProgress = min(abs(dragOffset) / 150, 1.0)
        let backPeekY: CGFloat = isCompact ? 10 : 15

        if isFront {
            return dragProgress * backPeekY
        } else {
            return backPeekY * (1.0 - dragProgress)
        }
    }

    private func opacity(for cardIndex: Int) -> CGFloat {
        let isFront = cardIndex == frontCardIndex
        let dragProgress = min(abs(dragOffset) / 150, 1.0)

        if isFront {
            return 1.0 - (dragProgress * 0.3)
        } else {
            return 0.7 + (dragProgress * 0.3)
        }
    }

    // MARK: - Card Views

    @ViewBuilder
    private func cardView(for index: Int, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)

            Group {
                if index == 0 {
                    enforceModeContent
                } else {
                    smartModeContent
                }
            }
            .padding(isCompact ? 12 : 20)
        }
        .frame(width: width, height: height)
    }

    @ObservedObject var cameraService = CameraAccessService.shared

    private var enforceModeContent: some View {
        VStack(spacing: isCompact ? 10 : 16) {
            Image(systemName: "video.fill")
                .font(
                    .system(
                        size: isCompact
                            ? AdaptiveLayout.Font.cardIconSmall : AdaptiveLayout.Font.cardIcon)
                )
                .foregroundStyle(Color.accentColor)

            Text("Enforce Mode")
                .font(isCompact ? .headline : .title2)
                .fontWeight(.bold)

            if !cameraService.hasCameraHardware {
                Text("Camera hardware not detected")
                    .font(isCompact ? .caption : .subheadline)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                Text("Use your camera to ensure you take breaks")
                    .font(isCompact ? .caption : .subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: isCompact ? 10 : 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable Enforce Mode")
                            .font(isCompact ? .subheadline : .headline)
                        if !cameraService.hasCameraHardware {
                            Text("No camera hardware detected")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else {
                            Text("Camera activates before lookaway reminders")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: {
                                settingsManager.isTimerEnabled(for: .lookAway)
                                    || settingsManager.isTimerEnabled(for: .blink)
                                    || settingsManager.isTimerEnabled(for: .posture)
                            },
                            set: { newValue in
                                if newValue {
                                    Task { @MainActor in
                                        try await cameraService.requestCameraAccess()
                                    }
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .disabled(!cameraService.hasCameraHardware)
                    .controlSize(isCompact ? .small : .regular)
                }
                .padding(isCompact ? 10 : 16)
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Camera Access")
                            .font(isCompact ? .subheadline : .headline)

                        if !cameraService.hasCameraHardware {
                            Label("No camera", systemImage: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        } else if cameraService.isCameraAuthorized {
                            Label("Authorized", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        } else if let error = cameraService.cameraError {
                            Label(
                                error.localizedDescription,
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        } else {
                            Label("Not authorized", systemImage: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !cameraService.isCameraAuthorized {
                        Button("Request Access") {
                            Task { @MainActor in
                                do {
                                    try await cameraService.requestCameraAccess()
                                } catch {
                                    print("Camera access failed: \(error.localizedDescription)")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(isCompact ? .small : .regular)
                    }
                }
                .padding(isCompact ? 10 : 16)
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
            }

            Spacer()
        }
    }

    private var smartModeContent: some View {
        VStack(spacing: isCompact ? 10 : 16) {
            Image(systemName: "brain.fill")
                .font(
                    .system(
                        size: isCompact
                            ? AdaptiveLayout.Font.cardIconSmall : AdaptiveLayout.Font.cardIcon)
                )
                .foregroundStyle(.purple)

            Text("Smart Mode")
                .font(isCompact ? .headline : .title2)
                .fontWeight(.bold)

            Text("Automatically manage timers based on activity")
                .font(isCompact ? .caption : .subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            VStack(spacing: isCompact ? 8 : 12) {
                smartModeToggle(
                    icon: "arrow.up.left.and.arrow.down.right",
                    iconColor: .blue,
                    title: "Auto-pause on Fullscreen",
                    subtitle: "Pause during videos, games, presentations",
                    isOn: $settingsManager.settings.smartMode.autoPauseOnFullscreen
                )

                smartModeToggle(
                    icon: "moon.zzz.fill",
                    iconColor: .indigo,
                    title: "Auto-pause on Idle",
                    subtitle: "Pause when you're inactive",
                    isOn: $settingsManager.settings.smartMode.autoPauseOnIdle
                )

                #if TRACK_READY
                    smartModeToggle(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .green,
                        title: "Track Usage Statistics",
                        subtitle: "Monitor active and idle time",
                        isOn: $settingsManager.settings.smartMode.trackUsage
                    )
                #endif
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func smartModeToggle(
        icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: isCompact ? 20 : 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(isCompact ? .caption : .subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, isCompact ? 8 : 12)
        .padding(.vertical, isCompact ? 6 : 10)
        .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 10))
    }

    // MARK: - Gestures & Navigation

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold: CGFloat = 80
                let shouldSwap =
                    abs(value.translation.width) > threshold
                    || abs(value.predictedEndTranslation.width) > 150

                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    if shouldSwap {
                        frontCardIndex = 1 - frontCardIndex
                    }
                    dragOffset = 0
                    isDragging = false
                }
            }
    }

    private func swapCards() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            frontCardIndex = 1 - frontCardIndex
        }
    }
}

#Preview("Additional Modifiers View") {
    AdditionalModifiersView(settingsManager: SettingsManager.shared)
}
