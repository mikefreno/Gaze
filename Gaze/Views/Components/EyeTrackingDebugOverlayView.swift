//
//  EyeTrackingDebugOverlayView.swift
//  Gaze
//
//  Created by Mike Freno on 1/31/26.
//

import SwiftUI

struct EyeTrackingDebugOverlayView: View {
    let debugState: EyeTrackingDebugState
    let viewSize: CGSize

    var body: some View {
        ZStack {
            if let leftRect = debugState.leftEyeRect,
               let imageSize = debugState.imageSize {
                drawEyeRect(leftRect, imageSize: imageSize, color: .cyan)
            }

            if let rightRect = debugState.rightEyeRect,
               let imageSize = debugState.imageSize {
                drawEyeRect(rightRect, imageSize: imageSize, color: .yellow)
            }

            if let leftPupil = debugState.leftPupil,
               let imageSize = debugState.imageSize {
                drawPupil(leftPupil, imageSize: imageSize, color: .red)
            }

            if let rightPupil = debugState.rightPupil,
               let imageSize = debugState.imageSize {
                drawPupil(rightPupil, imageSize: imageSize, color: .red)
            }
        }
    }

    private func drawEyeRect(_ rect: CGRect, imageSize: CGSize, color: Color) -> some View {
        let mapped = mapRect(rect, imageSize: imageSize)
        return Rectangle()
            .stroke(color, lineWidth: 2)
            .frame(width: mapped.size.width, height: mapped.size.height)
            .position(x: mapped.midX, y: mapped.midY)
    }

    private func drawPupil(_ point: CGPoint, imageSize: CGSize, color: Color) -> some View {
        let mapped = mapPoint(point, imageSize: imageSize)
        return Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .position(x: mapped.x, y: mapped.y)
    }

    private func mapRect(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let mappedOrigin = mapPoint(rect.origin, imageSize: imageSize)
        let mappedMax = mapPoint(CGPoint(x: rect.maxX, y: rect.maxY), imageSize: imageSize)

        let width = abs(mappedMax.x - mappedOrigin.x)
        let height = abs(mappedMax.y - mappedOrigin.y)

        return CGRect(
            x: min(mappedOrigin.x, mappedMax.x),
            y: min(mappedOrigin.y, mappedMax.y),
            width: width,
            height: height
        )
    }

    private func mapPoint(_ point: CGPoint, imageSize: CGSize) -> CGPoint {
        let rawImageWidth = imageSize.width
        let rawImageHeight = imageSize.height

        let imageAspect = rawImageWidth / rawImageHeight
        let viewAspect = viewSize.width / viewSize.height

        let scale: CGFloat
        let offsetX: CGFloat
        let offsetY: CGFloat

        if imageAspect > viewAspect {
            scale = viewSize.height / rawImageHeight
            offsetX = (viewSize.width - rawImageWidth * scale) / 2
            offsetY = 0
        } else {
            scale = viewSize.width / rawImageWidth
            offsetX = 0
            offsetY = (viewSize.height - rawImageHeight * scale) / 2
        }

        let mirroredX = rawImageWidth - point.x
        let screenX = mirroredX * scale + offsetX
        let screenY = point.y * scale + offsetY

        return CGPoint(x: screenX, y: screenY)
    }
}
