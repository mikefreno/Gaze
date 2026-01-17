//
//  CalibrationOverlayView.swift
//  Gaze
//
//  Fullscreen overlay view for eye tracking calibration targets.
//

import SwiftUI
import Combine
import AVFoundation

struct CalibrationOverlayView: View {
    @StateObject private var calibrationManager = CalibrationManager.shared
    @StateObject private var eyeTrackingService = EyeTrackingService.shared
    @StateObject private var viewModel = CalibrationOverlayViewModel()
    
    let onDismiss: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Camera preview at 50% opacity (mirrored for natural feel)
                if let previewLayer = eyeTrackingService.previewLayer {
                    CameraPreviewView(previewLayer: previewLayer, borderColor: .clear)
                        .scaleEffect(x: -1, y: 1)
                        .opacity(0.5)
                        .ignoresSafeArea()
                }
                
                if let error = viewModel.showError {
                    errorView(error)
                } else if !viewModel.cameraStarted {
                    startingCameraView
                } else if calibrationManager.isCalibrating {
                    calibrationContentView(screenSize: geometry.size)
                } else if viewModel.calibrationStarted && calibrationManager.calibrationData.isComplete {
                    // Only show completion if we started calibration this session AND it completed
                    completionView
                } else if viewModel.calibrationStarted {
                    // Calibration was started but not yet complete - show content
                    calibrationContentView(screenSize: geometry.size)
                }
            }
        }
        .task {
            await viewModel.startCamera(eyeTrackingService: eyeTrackingService, calibrationManager: calibrationManager)
        }
        .onDisappear {
            viewModel.cleanup(eyeTrackingService: eyeTrackingService, calibrationManager: calibrationManager)
        }
        .onChange(of: calibrationManager.currentStep) { oldStep, newStep in
            if newStep != nil && oldStep != newStep {
                viewModel.startStepCountdown(calibrationManager: calibrationManager)
            }
        }
    }
    
    // MARK: - Starting Camera View
    
    private var startingCameraView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(2)
                .tint(.white)
            
            Text("Starting camera...")
                .font(.title2)
                .foregroundStyle(.white)
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Camera Error")
                .font(.title)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.body)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
            
            Button("Close") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 20)
        }
        .padding(40)
    }
    
    // MARK: - Calibration Content
    
    private func calibrationContentView(screenSize: CGSize) -> some View {
        ZStack {
            VStack {
                progressBar
                Spacer()
            }
            
            if let step = calibrationManager.currentStep {
                calibrationTarget(for: step, screenSize: screenSize)
            }
            
            VStack {
                Spacer()
                HStack {
                    cancelButton
                    Spacer()
                    if !calibrationManager.isCollectingSamples {
                        skipButton
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
            
            // Face detection indicator
            VStack {
                HStack {
                    Spacer()
                    faceDetectionIndicator
                }
                Spacer()
            }
        }
    }
    
    // MARK: - Progress Bar
    
    private var progressBar: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Calibrating...")
                    .foregroundStyle(.white)
                Spacer()
                Text(calibrationManager.progressText)
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            ProgressView(value: calibrationManager.progress)
                .progressViewStyle(.linear)
                .tint(.blue)
        }
        .padding()
        .background(Color.black.opacity(0.7))
    }
    
    // MARK: - Face Detection Indicator
    
    private var faceDetectionIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(viewModel.stableFaceDetected ? Color.green : Color.red)
                .frame(width: 12, height: 12)
            
            Text(viewModel.stableFaceDetected ? "Face detected" : "No face detected")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .padding()
        .animation(.easeInOut(duration: 0.3), value: viewModel.stableFaceDetected)
    }
    
    // MARK: - Calibration Target
    
    @ViewBuilder
    private func calibrationTarget(for step: CalibrationStep, screenSize: CGSize) -> some View {
        let position = targetPosition(for: step, screenSize: screenSize)
        
        VStack(spacing: 20) {
            ZStack {
                // Outer ring (pulsing when counting down)
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                    .frame(width: 100, height: 100)
                    .scaleEffect(viewModel.isCountingDown ? 1.2 : 1.0)
                    .animation(
                        viewModel.isCountingDown 
                            ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                            : .default,
                        value: viewModel.isCountingDown)
                
                // Progress ring when collecting
                if calibrationManager.isCollectingSamples {
                    Circle()
                        .trim(from: 0, to: CGFloat(calibrationManager.samplesCollected) / 30.0)
                        .stroke(Color.green, lineWidth: 4)
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: calibrationManager.samplesCollected)
                }
                
                // Inner circle
                Circle()
                    .fill(calibrationManager.isCollectingSamples ? Color.green : Color.blue)
                    .frame(width: 60, height: 60)
                    .animation(.easeInOut(duration: 0.3), value: calibrationManager.isCollectingSamples)
                
                // Countdown number or collecting indicator
                if viewModel.isCountingDown && viewModel.countdownValue > 0 {
                    Text("\(viewModel.countdownValue)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)
                } else if calibrationManager.isCollectingSamples {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            
            Text(instructionText(for: step))
                .font(.title2)
                .foregroundStyle(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 15)
                .background(Color.black.opacity(0.7))
                .cornerRadius(10)
        }
        .position(position)
    }
    
    private func instructionText(for step: CalibrationStep) -> String {
        if viewModel.isCountingDown && viewModel.countdownValue > 0 {
            return "Get ready..."
        } else if calibrationManager.isCollectingSamples {
            return "Look at the target"
        } else {
            return step.instructionText
        }
    }
    
    // MARK: - Buttons
    
    private var skipButton: some View {
        Button {
            viewModel.skipCurrentStep(calibrationManager: calibrationManager)
        } label: {
            Text("Skip")
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var cancelButton: some View {
        Button {
            viewModel.cleanup(eyeTrackingService: eyeTrackingService, calibrationManager: calibrationManager)
            onDismiss()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "xmark")
                Text("Cancel")
            }
            .foregroundStyle(.white.opacity(0.7))
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.escape, modifiers: [])
    }
    
    // MARK: - Completion View
    
    private var completionView: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            
            Text("Calibration Complete!")
                .font(.largeTitle)
                .foregroundStyle(.white)
                .fontWeight(.bold)
            
            Text("Your eye tracking has been calibrated successfully.")
                .font(.title3)
                .foregroundStyle(.gray)
            
            Button("Done") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [])
            .padding(.top, 20)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                onDismiss()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func targetPosition(for step: CalibrationStep, screenSize: CGSize) -> CGPoint {
        let width = screenSize.width
        let height = screenSize.height
        
        let centerX = width / 2
        let centerY = height / 2
        let marginX: CGFloat = 150
        let marginY: CGFloat = 120
        
        switch step {
        case .center:
            return CGPoint(x: centerX, y: centerY)
        case .left:
            return CGPoint(x: centerX - width / 4, y: centerY)
        case .right:
            return CGPoint(x: centerX + width / 4, y: centerY)
        case .farLeft:
            return CGPoint(x: marginX, y: centerY)
        case .farRight:
            return CGPoint(x: width - marginX, y: centerY)
        case .up:
            return CGPoint(x: centerX, y: marginY)
        case .down:
            return CGPoint(x: centerX, y: height - marginY)
        case .topLeft:
            return CGPoint(x: marginX, y: marginY)
        case .topRight:
            return CGPoint(x: width - marginX, y: marginY)
        case .bottomLeft:
            return CGPoint(x: marginX, y: height - marginY)
        case .bottomRight:
            return CGPoint(x: width - marginX, y: height - marginY)
        }
    }
}

// MARK: - ViewModel

@MainActor
class CalibrationOverlayViewModel: ObservableObject {
    @Published var countdownValue = 1
    @Published var isCountingDown = false
    @Published var cameraStarted = false
    @Published var showError: String?
    @Published var calibrationStarted = false
    @Published var stableFaceDetected = false  // Debounced face detection
    
    private var countdownTask: Task<Void, Never>?
    private var faceDetectionCancellable: AnyCancellable?
    private var lastFaceDetectedTime: Date = .distantPast
    private let faceDetectionDebounce: TimeInterval = 0.5  // 500ms debounce
    
    func startCamera(eyeTrackingService: EyeTrackingService, calibrationManager: CalibrationManager) async {
        do {
            try await eyeTrackingService.startEyeTracking()
            cameraStarted = true
            
            // Set up debounced face detection
            setupFaceDetectionObserver(eyeTrackingService: eyeTrackingService)
            
            // Small delay to let camera stabilize
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Reset any previous calibration data before starting fresh
            calibrationManager.resetForNewCalibration()
            calibrationManager.startCalibration()
            calibrationStarted = true
            startStepCountdown(calibrationManager: calibrationManager)
        } catch {
            showError = "Failed to start camera: \(error.localizedDescription)"
        }
    }
    
    private func setupFaceDetectionObserver(eyeTrackingService: EyeTrackingService) {
        faceDetectionCancellable = eyeTrackingService.$faceDetected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] detected in
                guard let self = self else { return }
                
                if detected {
                    // Face detected - update immediately
                    self.lastFaceDetectedTime = Date()
                    self.stableFaceDetected = true
                } else {
                    // Face lost - only update after debounce period
                    let timeSinceLastDetection = Date().timeIntervalSince(self.lastFaceDetectedTime)
                    if timeSinceLastDetection > self.faceDetectionDebounce {
                        self.stableFaceDetected = false
                    }
                }
            }
    }
    
    func cleanup(eyeTrackingService: EyeTrackingService, calibrationManager: CalibrationManager) {
        countdownTask?.cancel()
        countdownTask = nil
        faceDetectionCancellable?.cancel()
        faceDetectionCancellable = nil
        isCountingDown = false
        
        if calibrationManager.isCalibrating {
            calibrationManager.cancelCalibration()
        }
        
        eyeTrackingService.stopEyeTracking()
    }
    
    func skipCurrentStep(calibrationManager: CalibrationManager) {
        countdownTask?.cancel()
        countdownTask = nil
        isCountingDown = false
        calibrationManager.skipStep()
    }
    
    func startStepCountdown(calibrationManager: CalibrationManager) {
        countdownTask?.cancel()
        countdownTask = nil
        countdownValue = 1
        isCountingDown = true
        
        countdownTask = Task { @MainActor in
            // Just 1 second countdown
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { return }
            
            // Done counting, start collecting
            isCountingDown = false
            countdownValue = 0
            calibrationManager.startCollectingSamples()
        }
    }
}

#Preview {
    CalibrationOverlayView(onDismiss: {})
}

