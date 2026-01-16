//
//  GazeOverlayView.swift
//  Gaze
//
//  Created by Claude on 1/16/26.
//

import SwiftUI

struct GazeOverlayView: View {
    @ObservedObject var eyeTrackingService: EyeTrackingService
    
    var body: some View {
        VStack(spacing: 8) {
            inFrameIndicator
            gazeDirectionGrid
            ratioDebugView
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
                .foregroundColor(.white)
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
                        let isActive = currentPos.x == col && currentPos.y == row && eyeTrackingService.isInFrame
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
                .foregroundColor(isActive ? .white : .white.opacity(0.6))
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
            if let leftH = eyeTrackingService.debugLeftPupilRatio,
               let rightH = eyeTrackingService.debugRightPupilRatio {
                let avgH = (leftH + rightH) / 2.0
                Text("H: \(String(format: "%.2f", avgH))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
            
            if let leftV = eyeTrackingService.debugLeftVerticalRatio,
               let rightV = eyeTrackingService.debugRightVerticalRatio {
                let avgV = (leftV + rightV) / 2.0
                Text("V: \(String(format: "%.2f", avgV))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.5))
        )
    }
}

#Preview {
    ZStack {
        Color.gray
        GazeOverlayView(eyeTrackingService: EyeTrackingService.shared)
    }
    .frame(width: 300, height: 200)
}
