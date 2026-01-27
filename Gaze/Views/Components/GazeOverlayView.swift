//
//  GazeOverlayView.swift
//  Gaze
//
//  Created by Mike Freno on 1/16/26.
//

import SwiftUI

struct GazeOverlayView: View {
    @ObservedObject var eyeTrackingService: EyeTrackingService

    var body: some View {
        VStack(spacing: 8) {
            inFrameIndicator
            gazeDirectionGrid
            ratioDebugView
            eyeImagesDebugView
        }
        .padding(12)
    }

    private var inFrameIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(eyeTrackingService.isInFrame ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            Text(eyeTrackingService.isInFrame ? "In Frame" : "No Face")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.6))
        )
    }

    private var gazeDirectionGrid: some View {
        let currentDirection = eyeTrackingService.gazeDirection
        let currentPos = currentDirection.gridPosition

        return VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<3, id: \.self) { col in
                        let isActive =
                            currentPos.x == col && currentPos.y == row
                            && eyeTrackingService.isInFrame
                        gridCell(row: row, col: col, isActive: isActive)
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }

    private func gridCell(row: Int, col: Int, isActive: Bool) -> some View {
        let direction = directionFor(row: row, col: col)

        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.green : Color.white.opacity(0.2))

            Text(direction.rawValue)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(isActive ? .white : .white.opacity(0.6))
        }
        .frame(width: 28, height: 28)
    }

    private func directionFor(row: Int, col: Int) -> GazeDirection {
        switch (col, row) {
        case (0, 0): return .upLeft
        case (1, 0): return .up
        case (2, 0): return .upRight
        case (0, 1): return .left
        case (1, 1): return .center
        case (2, 1): return .right
        case (0, 2): return .downLeft
        case (1, 2): return .down
        case (2, 2): return .downRight
        default: return .center
        }
    }

    private var ratioDebugView: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Show individual L/R ratios
            HStack(spacing: 8) {
                if let leftH = eyeTrackingService.debugLeftPupilRatio {
                    Text("L.H: \(String(format: "%.2f", leftH))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                if let rightH = eyeTrackingService.debugRightPupilRatio {
                    Text("R.H: \(String(format: "%.2f", rightH))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            HStack(spacing: 8) {
                if let leftV = eyeTrackingService.debugLeftVerticalRatio {
                    Text("L.V: \(String(format: "%.2f", leftV))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
                if let rightV = eyeTrackingService.debugRightVerticalRatio {
                    Text("R.V: \(String(format: "%.2f", rightV))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }

            // Show averaged ratios
            if let leftH = eyeTrackingService.debugLeftPupilRatio,
                let rightH = eyeTrackingService.debugRightPupilRatio,
                let leftV = eyeTrackingService.debugLeftVerticalRatio,
                let rightV = eyeTrackingService.debugRightVerticalRatio
            {
                let avgH = (leftH + rightH) / 2.0
                let avgV = (leftV + rightV) / 2.0
                Text("Avg H:\(String(format: "%.2f", avgH)) V:\(String(format: "%.2f", avgV))")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.5))
        )
    }

    private var eyeImagesDebugView: some View {
        HStack(spacing: 12) {
            // Left eye
            VStack(spacing: 4) {
                Text("Left")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    eyeImageView(
                        image: eyeTrackingService.debugLeftEyeInput,
                        pupilPosition: eyeTrackingService.debugLeftPupilPosition,
                        eyeSize: eyeTrackingService.debugLeftEyeSize,
                        label: "Input"
                    )
                    eyeImageView(
                        image: eyeTrackingService.debugLeftEyeProcessed,
                        pupilPosition: eyeTrackingService.debugLeftPupilPosition,
                        eyeSize: eyeTrackingService.debugLeftEyeSize,
                        label: "Proc"
                    )
                }
            }

            // Right eye
            VStack(spacing: 4) {
                Text("Right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    eyeImageView(
                        image: eyeTrackingService.debugRightEyeInput,
                        pupilPosition: eyeTrackingService.debugRightPupilPosition,
                        eyeSize: eyeTrackingService.debugRightEyeSize,
                        label: "Input"
                    )
                    eyeImageView(
                        image: eyeTrackingService.debugRightEyeProcessed,
                        pupilPosition: eyeTrackingService.debugRightPupilPosition,
                        eyeSize: eyeTrackingService.debugRightEyeSize,
                        label: "Proc"
                    )
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.5))
        )
    }

    private func eyeImageView(
        image: NSImage?, pupilPosition: PupilPosition?, eyeSize: CGSize?, label: String
    ) -> some View {
        let displaySize: CGFloat = 50

        return VStack(spacing: 2) {
            ZStack {
                if let nsImage = image {
                    Image(nsImage: nsImage)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: displaySize, height: displaySize)

                    // Draw pupil position marker
                    if let pupil = pupilPosition, let size = eyeSize, size.width > 0,
                        size.height > 0
                    {
                        let scaleX = displaySize / size.width
                        let scaleY = displaySize / size.height
                        let scale = min(scaleX, scaleY)
                        let scaledWidth = size.width * scale
                        let scaledHeight = size.height * scale

                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                            .offset(
                                x: (pupil.x * scale) - (scaledWidth / 2),
                                y: (pupil.y * scale) - (scaledHeight / 2)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: displaySize, height: displaySize)
                    Text("--")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(width: displaySize, height: displaySize)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.white.opacity(0.7))
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        GazeOverlayView(eyeTrackingService: EyeTrackingService.shared)
    }
    .frame(width: 400, height: 400)
}
