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
    
    func makeNSView(context: Context) -> NSView {
        let view = PreviewContainerView()
        view.wantsLayer = true
        
        previewLayer.frame = view.bounds
        view.layer?.addSublayer(previewLayer)
        
        updateBorder(view: view, color: borderColor)
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        previewLayer.frame = nsView.bounds
        updateBorder(view: nsView, color: borderColor)
    }
    
    private func updateBorder(view: NSView, color: NSColor) {
        view.layer?.borderColor = color.cgColor
        view.layer?.borderWidth = 4
        view.layer?.cornerRadius = 12
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
