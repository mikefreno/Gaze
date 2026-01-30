//
//  AdditionalModifiersView.swift
//  Gaze
//
//  Created by Mike Freno on 1/18/26.
//

import AVFoundation
import SwiftUI

struct AdditionalModifiersView: View {
    @Bindable var settingsManager: SettingsManager
    @State private var frontCardIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isTestModeActive = false
    @State private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var showAdvancedSettings = false
    @State private var showCalibrationWindow = false
    @State private var isViewActive = false
    @State private var isProcessingToggle = false
    @ObservedObject var cameraService = CameraAccessService.shared
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
                #if !DEBUG
                    Text("More to come soon")
                        .font(isCompact ? .subheadline : .title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                #endif

                Spacer()

                ZStack {
                    #if DEBUG
                        setupCard(
                            presentation: .card,
                            content: EnforceModeSetupContent(
                                settingsManager: settingsManager,
                                presentation: .card,
                                isTestModeActive: $isTestModeActive,
                                cachedPreviewLayer: $cachedPreviewLayer,
                                showAdvancedSettings: $showAdvancedSettings,
                                showCalibrationWindow: $showCalibrationWindow,
                                isViewActive: $isViewActive,
                                isProcessingToggle: isProcessingToggle,
                                handleEnforceModeToggle: { enabled in
                                    if enabled {
                                        Task { @MainActor in
                                            try await cameraService.requestCameraAccess()
                                        }
                                    }
                                }
                            ),
                            width: cardWidth,
                            height: cardHeight,
                            index: 0
                        )
                    #endif
                    setupCard(
                        presentation: .card,
                        content: SmartModeSetupContent(
                            settingsManager: settingsManager,
                            presentation: .card
                        ),
                        width: cardWidth,
                        height: cardHeight,
                        index: 1
                    )
                }
                .padding(isCompact ? 12 : 20)
                .gesture(dragGesture)

                Spacer()

                #if DEBUG
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
    private func setupCard(
        presentation: SetupPresentation,
        content: some View,
        width: CGFloat,
        height: CGFloat,
        index: Int
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)

            content
                .padding(isCompact ? 12 : 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(width: width, height: height)
        .zIndex(zIndex(for: index))
        .scaleEffect(scale(for: index))
        .offset(x: xOffset(for: index), y: yOffset(for: index))
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
