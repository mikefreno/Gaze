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
    
    private let cardWidth: CGFloat = 480
    private let cardHeight: CGFloat = 480
    private let backCardOffset: CGFloat = 30
    private let backCardScale: CGFloat = 0.92
    
    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "slider.horizontal.3", title: "Additional Options", color: .purple)
            
            Text("Optional features to enhance your experience")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            
            Spacer()
            
            // Card stack
            ZStack {
                // Card 0 (Enforce Mode)
                cardView(for: 0)
                    .zIndex(zIndex(for: 0))
                    .scaleEffect(scale(for: 0))
                    .offset(x: xOffset(for: 0), y: yOffset(for: 0))
                    .opacity(opacity(for: 0))
                
                // Card 1 (Smart Mode)
                cardView(for: 1)
                    .zIndex(zIndex(for: 1))
                    .scaleEffect(scale(for: 1))
                    .offset(x: xOffset(for: 1), y: yOffset(for: 1))
                    .opacity(opacity(for: 1))
            }
            .gesture(dragGesture)
            
            Spacer()
            
            // Navigation controls
            HStack(spacing: 20) {
                Button(action: { swapCards() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffectIfAvailable(GlassStyle.regular.interactive(), in: .rect(cornerRadius: 10))
                .disabled(frontCardIndex == 0)
                .opacity(frontCardIndex == 0 ? 0.4 : 1)
                
                // Page indicators with labels
                HStack(spacing: 16) {
                    cardIndicator(index: 0, icon: "video.fill", label: "Enforce")
                    cardIndicator(index: 1, icon: "brain.fill", label: "Smart")
                }
                
                Button(action: { swapCards() }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .glassEffectIfAvailable(GlassStyle.regular.interactive(), in: .rect(cornerRadius: 10))
                .disabled(frontCardIndex == 1)
                .opacity(frontCardIndex == 1 ? 0.4 : 1)
            }
            .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(index == frontCardIndex ? .primary : .secondary)
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
        let backPeekY: CGFloat = 15
        
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
    private func cardView(for index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.8))
                .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            
            Group {
                if index == 0 {
                    enforceModeContent
                } else {
                    smartModeContent
                }
            }
            .padding(20)
        }
        .frame(width: cardWidth, height: cardHeight)
    }
    
    private var enforceModeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
            
            Text("Enforce Mode")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Use your camera to ensure you take breaks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable Enforce Mode")
                            .font(.headline)
                        Text("Camera activates before lookaway reminders")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $settingsManager.settings.enforcementMode)
                        .labelsHidden()
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Camera Access")
                            .font(.headline)
                        
                        if CameraAccessService.shared.isCameraAuthorized {
                            Label("Authorized", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else if let error = CameraAccessService.shared.cameraError {
                            Label(error.localizedDescription, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else {
                            Label("Not authorized", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if !CameraAccessService.shared.isCameraAuthorized {
                        Button("Request Access") {
                            Task { @MainActor in
                                do {
                                    try await CameraAccessService.shared.requestCameraAccess()
                                } catch {
                                    print("Camera access failed: \(error.localizedDescription)")
                                }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .glassEffectIfAvailable(GlassStyle.regular, in: .rect(cornerRadius: 12))
            }
            
            Spacer()
        }
    }
    
    private var smartModeContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.fill")
                .font(.system(size: 40))
                .foregroundStyle(.purple)
            
            Text("Smart Mode")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Automatically manage timers based on activity")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            VStack(spacing: 12) {
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
                
                smartModeToggle(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .green,
                    title: "Track Usage Statistics",
                    subtitle: "Monitor active and idle time",
                    isOn: $settingsManager.settings.smartMode.trackUsage
                )
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func smartModeToggle(icon: String, iconColor: Color, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
                let shouldSwap = abs(value.translation.width) > threshold ||
                                 abs(value.predictedEndTranslation.width) > 150
                
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
