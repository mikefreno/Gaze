//
//  PupilOverlayView.swift
//  Gaze
//
//  Created by Claude on 1/16/26.
//

import SwiftUI

/// Draws pupil detection markers directly on top of the camera preview
struct PupilOverlayView: View {
    @ObservedObject var eyeTrackingService: EyeTrackingService

    var body: some View {
        GeometryReader { geometry in
            let viewSize = geometry.size

            // Draw eye regions and pupil markers
            ZStack {
                // Left eye
                if let leftRegion = eyeTrackingService.debugLeftEyeRegion,
                    let leftPupil = eyeTrackingService.debugLeftPupilPosition,
                    let imageSize = eyeTrackingService.debugImageSize
                {
                    EyeOverlayShape(
                        eyeRegion: leftRegion,
                        pupilPosition: leftPupil,
                        imageSize: imageSize,
                        viewSize: viewSize,
                        color: .cyan,
                        label: "L"
                    )
                }

                // Right eye
                if let rightRegion = eyeTrackingService.debugRightEyeRegion,
                    let rightPupil = eyeTrackingService.debugRightPupilPosition,
                    let imageSize = eyeTrackingService.debugImageSize
                {
                    EyeOverlayShape(
                        eyeRegion: rightRegion,
                        pupilPosition: rightPupil,
                        imageSize: imageSize,
                        viewSize: viewSize,
                        color: .yellow,
                        label: "R"
                    )
                }
            }
        }
    }
}

/// Helper view for drawing eye overlay
private struct EyeOverlayShape: View {
    let eyeRegion: EyeRegion
    let pupilPosition: PupilPosition
    let imageSize: CGSize
    let viewSize: CGSize
    let color: Color
    let label: String

    private var transformedCoordinates: (eyeRect: CGRect, pupilPoint: CGPoint) {
        // Standard macOS Camera Coordinate System (Landscape):
        // Raw Buffer:
        //   - Origin (0,0) is Top-Left
        //   - X increases Right
        //   - Y increases Down
        //
        // Preview Layer (Mirrored):
        //   - Appears like a mirror
        //   - Screen X increases Right
        //   - Screen Y increases Down
        //   - BUT the image content is flipped horizontally
        //     (Raw Left is Screen Right, Raw Right is Screen Left)

        // Use dimensions directly (no rotation swap)
        let rawImageWidth = imageSize.width
        let rawImageHeight = imageSize.height

        // Calculate aspect-fill scaling
        // We compare the raw aspect ratio to the view aspect ratio
        let imageAspect = rawImageWidth / rawImageHeight
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if imageAspect > viewAspect {
            // Image is wider than view - crop sides (pillarbox behavior in aspect fill)
            // Wait, aspect fill means we fill the view, so we crop the excess.
            // If image is wider, we scale by height to fill height, and crop width.
            scale = viewSize.height / rawImageHeight
            offsetX = (viewSize.width - rawImageWidth * scale) / 2
            offsetY = 0
        } else {
            // Image is taller than view (or view is wider) - scale by width, crop height
            scale = viewSize.width / rawImageWidth
            offsetX = 0
            offsetY = (viewSize.height - rawImageHeight * scale) / 2
        }

        // Transform Eye Region
        // Mirroring X: The 'left' of the raw image becomes the 'right' of the screen
        // Raw Rect: x, y, w, h
        // Mirrored X = ImageWidth - (x + w)
        let eyeRawX = eyeRegion.frame.origin.x
        let eyeRawY = eyeRegion.frame.origin.y
        let eyeRawW = eyeRegion.frame.width
        let eyeRawH = eyeRegion.frame.height

        // Calculate Screen Coordinates
        let eyeScreenX = (rawImageWidth - (eyeRawX + eyeRawW)) * scale + offsetX
        let eyeScreenY = eyeRawY * scale + offsetY
        let eyeScreenW = eyeRawW * scale
        let eyeScreenH = eyeRawH * scale

        // Transform Pupil Position
        // Global Raw Pupil X = eyeRawX + pupilPosition.x
        // Global Raw Pupil Y = eyeRawY + pupilPosition.y
        let pupilGlobalRawX = eyeRawX + pupilPosition.x
        let pupilGlobalRawY = eyeRawY + pupilPosition.y

        // Mirror X for Pupil
        let pupilScreenX = (rawImageWidth - pupilGlobalRawX) * scale + offsetX
        let pupilScreenY = pupilGlobalRawY * scale + offsetY

        return (
            eyeRect: CGRect(x: eyeScreenX, y: eyeScreenY, width: eyeScreenW, height: eyeScreenH),
            pupilPoint: CGPoint(x: pupilScreenX, y: pupilScreenY)
        )
    }

    var body: some View {
        let coords = transformedCoordinates
        let eyeRect = coords.eyeRect
        let pupilPoint = coords.pupilPoint

        ZStack {
            // Eye region rectangle
            Rectangle()
                .stroke(color, lineWidth: 2)
                .frame(width: eyeRect.width, height: eyeRect.height)
                .position(x: eyeRect.midX, y: eyeRect.midY)

            // Pupil marker (red dot)
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .position(x: pupilPoint.x, y: pupilPoint.y)

            // Crosshair at pupil position
            Path { path in
                path.move(to: CGPoint(x: pupilPoint.x - 6, y: pupilPoint.y))
                path.addLine(to: CGPoint(x: pupilPoint.x + 6, y: pupilPoint.y))
                path.move(to: CGPoint(x: pupilPoint.x, y: pupilPoint.y - 6))
                path.addLine(to: CGPoint(x: pupilPoint.x, y: pupilPoint.y + 6))
            }
            .stroke(Color.red, lineWidth: 1)

            // Label
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .position(x: eyeRect.minX + 8, y: eyeRect.minY - 8)

            // Debug: Show raw coordinates
            Text("\(label): (\(Int(pupilPosition.x)), \(Int(pupilPosition.y)))")
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white)
                .background(.black.opacity(0.7))
                .position(x: eyeRect.midX, y: eyeRect.maxY + 10)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        PupilOverlayView(eyeTrackingService: EyeTrackingService.shared)
    }
    .frame(width: 400, height: 300)
}
