//
//  AdaptiveLayout.swift
//  Gaze
//
//  Created by Mike Freno on 1/19/26.
//

import SwiftUI

/// Adaptive layout constants for responsive UI scaling on different display sizes
enum AdaptiveLayout {
    /// Minimum window dimensions
    enum Window {
        static let minWidth: CGFloat = 700
        #if APPSTORE
            static let minHeight: CGFloat = 500
        #else
            static let minHeight: CGFloat = 600
        #endif

        static let defaultWidth: CGFloat = 900
        #if APPSTORE
            static let defaultHeight: CGFloat = 650
        #else
            static let defaultHeight: CGFloat = 800
        #endif
    }

    /// Content area constraints
    enum Content {
        /// Maximum width for content cards/sections
        static let maxWidth: CGFloat = 560
        /// Minimum width for content cards/sections
        static let minWidth: CGFloat = 400
        /// Ideal width for onboarding/welcome cards
        static let idealCardWidth: CGFloat = 520
    }

    /// Font sizes that scale based on available space
    enum Font {
        static let heroIcon: CGFloat = 60
        static let heroIconSmall: CGFloat = 48
        static let heroTitle: CGFloat = 28
        static let heroTitleSmall: CGFloat = 24
        static let cardIcon: CGFloat = 32
        static let cardIconSmall: CGFloat = 28
        
        /// Returns a responsive font size based on available space
        static func responsiveHeroIcon(for size: CGFloat) -> CGFloat {
            size < 600 ? heroIconSmall : heroIcon
        }
        
        /// Returns a responsive font size based on available space
        static func responsiveHeroTitle(for size: CGFloat) -> CGFloat {
            size < 600 ? heroTitleSmall : heroTitle
        }
        
        /// Returns a responsive font size based on available space
        static func responsiveCardIcon(for size: CGFloat) -> CGFloat {
            size < 600 ? cardIconSmall : cardIcon
        }
        
        /// Returns a responsive spacing value based on available space
        static func responsiveSpacing(for size: CGFloat) -> CGFloat {
            size < 600 ? AdaptiveLayout.Spacing.compact : AdaptiveLayout.Spacing.standard
        }
    }

    /// Spacing values
    enum Spacing {
        static let standard: CGFloat = 20
        static let compact: CGFloat = 12
        static let section: CGFloat = 30
        static let sectionCompact: CGFloat = 20
    }

    /// Card dimensions for swipeable cards
    enum Card {
        static let maxWidth: CGFloat = 520
        static let minWidth: CGFloat = 380
        static let maxHeight: CGFloat = 480
        static let minHeight: CGFloat = 360
        static let backOffset: CGFloat = 24
        static let backScale: CGFloat = 0.92
    }
    
    /// Returns a width that scales based on available screen size
    static func responsiveWidth(
        baseWidth: CGFloat,
        scaleFactor: CGFloat = 1.0,
        minScale: CGFloat = 0.6
    ) -> CGFloat {
        let scaleFactor = min(max(scaleFactor, minScale), 1.0)
        return baseWidth * scaleFactor
    }
    
    /// Returns a height that scales based on available screen size
    static func responsiveHeight(
        baseHeight: CGFloat,
        scaleFactor: CGFloat = 1.0,
        minScale: CGFloat = 0.6
    ) -> CGFloat {
        let scaleFactor = min(max(scaleFactor, minScale), 1.0)
        return baseHeight * scaleFactor
    }
}

/// Environment key to determine if we're in a compact layout
struct IsCompactLayoutKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var isCompactLayout: Bool {
        get { self[IsCompactLayoutKey.self] }
        set { self[IsCompactLayoutKey.self] = newValue }
    }
}

/// View modifier that adapts layout based on available size
struct AdaptiveContainerModifier: ViewModifier {
    @State private var isCompact = false
    let compactThreshold: CGFloat

    init(compactThreshold: CGFloat = 600) {
        self.compactThreshold = compactThreshold
    }

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .environment(\.isCompactLayout, geometry.size.height < compactThreshold)
                .onAppear {
                    isCompact = geometry.size.height < compactThreshold
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    isCompact = newHeight < compactThreshold
                }
        }
    }
}

extension View {
    /// Makes the view adapt its layout based on available space
    func adaptiveContainer(compactThreshold: CGFloat = 600) -> some View {
        modifier(AdaptiveContainerModifier(compactThreshold: compactThreshold))
    }
}
