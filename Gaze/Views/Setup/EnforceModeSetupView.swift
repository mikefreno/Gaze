//
//  EnforceModeSetupView.swift
//  Gaze
//
//  Created by Mike Freno on 1/13/26.
//

import AVFoundation
import SwiftUI

struct EnforceModeSetupView: View {
    @Bindable var settingsManager: SettingsManager
    @ObservedObject var cameraService = CameraAccessService.shared
    @ObservedObject var enforceModeService = EnforceModeService.shared

    @State private var isProcessingToggle = false
    @State private var isTestModeActive = false
    @State private var cachedPreviewLayer: AVCaptureVideoPreviewLayer?
    @State private var showDebugView = false
    @State private var isViewActive = false
    @State private var showAdvancedSettings = false
    @State private var showCalibrationWindow = false

    private var cameraHardwareAvailable: Bool {
        cameraService.hasCameraHardware
    }

    var body: some View {
        VStack(spacing: 0) {
            SetupHeader(icon: "video.fill", title: "Enforce Mode", color: .accentColor)

            EnforceModeSetupContent(
                settingsManager: settingsManager,
                presentation: .window,
                isTestModeActive: $isTestModeActive,
                cachedPreviewLayer: $cachedPreviewLayer,
                showAdvancedSettings: $showAdvancedSettings,
                showCalibrationWindow: $showCalibrationWindow,
                isViewActive: $isViewActive,
                isProcessingToggle: isProcessingToggle,
                handleEnforceModeToggle: { enabled in
                    print("🎛️ Toggle changed to: \(enabled)")
                    guard !isProcessingToggle else {
                        print("⚠️ Already processing toggle")
                        return
                    }
                    handleEnforceModeToggle(enabled: enabled)
                }
            )
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(.clear)
        .onAppear {
            isViewActive = true
        }
        .onDisappear {
            isViewActive = false
            // If the view disappeared and camera is still active, stop it
            if enforceModeService.isCameraActive {
                print("👁️ EnforceModeSetupView disappeared, stopping camera preview")
                enforceModeService.stopCamera()
            }
        }
    }
    private func handleEnforceModeToggle(enabled: Bool) {
        print("🎛️ handleEnforceModeToggle called with enabled: \(enabled)")
        isProcessingToggle = true

        Task { @MainActor in
            defer { isProcessingToggle = false }

            if enabled {
                guard cameraHardwareAvailable else {
                    print("⚠️ Cannot enable enforce mode - no camera hardware")
                    return
                }
                print("🎛️ Enabling enforce mode...")
                await enforceModeService.enableEnforceMode()
                print("🎛️ Enforce mode enabled: \(enforceModeService.isEnforceModeEnabled)")

                if !enforceModeService.isEnforceModeEnabled {
                    print("⚠️ Failed to activate, reverting toggle")
                }
            } else {
                print("🎛️ Disabling enforce mode...")
                enforceModeService.disableEnforceMode()
                // Clean up camera when disabling enforce mode
                if enforceModeService.isCameraActive {
                    print("👁️ Cleaning up camera on enforce mode disable")
                    enforceModeService.stopCamera()
                }
            }
        }
    }
}

#Preview {
    EnforceModeSetupView(settingsManager: SettingsManager.shared)
}
