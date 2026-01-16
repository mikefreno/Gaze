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
                   let imageSize = eyeTrackingService.debugImageSize {
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
                   let imageSize = eyeTrackingService.debugImageSize {
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
        // Calculate the aspect-fit scaling
        let imageAspect = imageSize.width / imageSize.height
        let viewAspect = viewSize.width / viewSize.height
        
        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat
        
        if imageAspect > viewAspect {
            // Image is wider - letterbox top/bottom
            scale = viewSize.width / imageSize.width
            offsetX = 0
            offsetY = (viewSize.height - imageSize.height * scale) / 2
        } else {
            // Image is taller - pillarbox left/right
            scale = viewSize.height / imageSize.height
            offsetX = (viewSize.width - imageSize.width * scale) / 2
            offsetY = 0
        }
        
        // Convert eye region frame from image coordinates to view coordinates
        // Note: The image is mirrored horizontally in the preview
        let mirroredX = imageSize.width - eyeRegion.frame.origin.x - eyeRegion.frame.width
        
        let eyeViewX = mirroredX * scale + offsetX
        let eyeViewY = eyeRegion.frame.origin.y * scale + offsetY
        let eyeViewWidth = eyeRegion.frame.width * scale
        let eyeViewHeight = eyeRegion.frame.height * scale
        
        // Calculate pupil position in view coordinates
        // pupilPosition is in local eye region coordinates (0 to eyeWidth, 0 to eyeHeight)
        // Need to mirror the X coordinate within the eye region
        let mirroredPupilX = eyeRegion.frame.width - pupilPosition.x
        let pupilViewX = eyeViewX + mirroredPupilX * scale
        let pupilViewY = eyeViewY + pupilPosition.y * scale
        
        return (
            eyeRect: CGRect(x: eyeViewX, y: eyeViewY, width: eyeViewWidth, height: eyeViewHeight),
            pupilPoint: CGPoint(x: pupilViewX, y: pupilViewY)
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
                .foregroundColor(color)
                .position(x: eyeRect.minX + 8, y: eyeRect.minY - 8)
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
