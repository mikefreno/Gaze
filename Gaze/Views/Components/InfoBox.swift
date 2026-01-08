//
//  InfoBox.swift
//  Gaze
//
//  Created by Mike Freno on 1/8/26.
//

import SwiftUI

struct InfoBox: View {
    let text: String
    let url: String?
    
    var body: some View {
        HStack(spacing: 12) {
            if let url = url, let urlObj = URL(string: url) {
                Button(action: {
                    #if os(iOS)
                    UIApplication.shared.open(urlObj)
                    #elseif os(macOS)
                    NSWorkspace.shared.open(urlObj)
                    #endif
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                }.buttonStyle(.plain)
            } else {
                Image(systemName: "info.circle")
                    .foregroundColor(.white)
            }
            Text(text)
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .glassEffect(.regular.tint(.blue), in: .rect(cornerRadius: 8))
    }
}

#Preview {
    InfoBox(text: "This is an informational message that provides helpful context to the user.", url: "https://www.healthline.com/health/eye-health/20-20-20-rule")
        .padding()
}