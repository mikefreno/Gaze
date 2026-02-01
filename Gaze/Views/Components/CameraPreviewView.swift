//
//  CameraPreviewView.swift
//  Gaze
//
//  Created by Mike Freno on 1/14/26.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer
    let borderColor: NSColor
    let showsBorder: Bool
    let cornerRadius: CGFloat

    init(
        previewLayer: AVCaptureVideoPreviewLayer,
        borderColor: NSColor,
        showsBorder: Bool = true,
        cornerRadius: CGFloat = 12
    ) {
        self.previewLayer = previewLayer
        self.borderColor = borderColor
        self.showsBorder = showsBorder
        self.cornerRadius = cornerRadius
    }
    
    func makeNSView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.wantsLayer = true
        
        // Add the preview layer once
        if view.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer !== previewLayer {
            view.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            previewLayer.frame = view.bounds
            view.layer?.addSublayer(previewLayer)
        }

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        
        updateBorder(view: view, color: borderColor)
        
        return view
    }
    
    func updateNSView(_ nsView: PreviewContainerView, context: Context) {
        // Only update border color and frame, don't recreate layer
        let currentLayer = nsView.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer
        
        if currentLayer !== previewLayer {
            // Layer changed, need to replace
            nsView.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
            previewLayer.frame = nsView.bounds
            nsView.layer?.addSublayer(previewLayer)
        } else {
            // Same layer, just update frame
            previewLayer.frame = nsView.bounds
        }

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        
        updateBorder(view: nsView, color: borderColor)
    }
    
    private func updateBorder(view: NSView, color: NSColor) {
        if showsBorder {
            view.layer?.borderColor = color.cgColor
            view.layer?.borderWidth = 4
        } else {
            view.layer?.borderWidth = 0
        }
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
    }
    
    class PreviewContainerView: NSView {
        override func layout() {
            super.layout()
            // Update sublayer frames when view is resized
            if let previewLayer = layer?.sublayers?.first as? AVCaptureVideoPreviewLayer {
                previewLayer.frame = bounds
            }
        }
    }
}
