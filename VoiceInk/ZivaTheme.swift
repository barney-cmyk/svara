import SwiftUI

/// Stitch-inspired design tokens for the Neuron Flame light/modern theme.
/// Used app-wide to keep colors and accents consistent.
enum ZivaTheme {
    // MARK: - Surfaces (light palette)
    static let surface              = Color(red: 0.980, green: 0.972, blue: 1.000) // #faf8ff
    static let surfaceContainerLowest = Color.white                                  // #ffffff
    static let surfaceContainerLow  = Color(red: 0.952, green: 0.952, blue: 1.000) // #f3f3ff
    static let surfaceContainer     = Color(red: 0.925, green: 0.929, blue: 0.980) // #ecedfa
    static let surfaceContainerHigh = Color(red: 0.906, green: 0.906, blue: 0.957) // #e7e7f4

    // MARK: - Foreground
    static let onSurface            = Color(red: 0.098, green: 0.106, blue: 0.141) // #191b24
    static let onSurfaceVariant     = Color(red: 0.259, green: 0.275, blue: 0.337) // #424656

    // MARK: - Accents
    static let primary              = Color(red: 0.000, green: 0.278, blue: 0.788) // #0047c9
    static let primaryFixed         = Color(red: 0.863, green: 0.882, blue: 1.000) // #dce1ff
    static let secondary            = Color(red: 0.345, green: 0.373, blue: 0.424) // #585f6c
    static let secondaryContainer   = Color(red: 0.863, green: 0.886, blue: 0.953) // #dce2f3
    static let tertiary             = Color(red: 0.612, green: 0.165, blue: 0.000) // #9c2a00
    static let tertiaryFixed        = Color(red: 1.000, green: 0.859, blue: 0.820) // #ffdbd1

    // MARK: - Borders
    static let outline              = Color(red: 0.451, green: 0.463, blue: 0.533) // #737688
    static let outlineVariant       = Color(red: 0.765, green: 0.773, blue: 0.851) // #c3c5d9
}

/// Convenience modifier to apply the Ziva light theme globally to a view tree.
/// Forces the SwiftUI color scheme to light and applies the brand primary as the global tint.
extension View {
    func zivaTheme() -> some View {
        self
            .preferredColorScheme(.light)
            .tint(ZivaTheme.primary)
    }
}

// MARK: - Liquid Glass adapter (macOS 26 Tahoe)
//
// Apple's Liquid Glass (WWDC25) is the navigation/chrome material in macOS 26+.
// We adopt it for floating chrome (recorder panel, sidebar pills, toolbars) but
// NOT for content surfaces (dashboard cards, hero banner — those stay Stitch).
//
// Every glass call is gated for macOS 26+. On macOS 14/15 we fall back to the
// existing `.ultraThinMaterial` system material — visually similar enough that
// the app still feels modern, but doesn't try to fake refraction.
extension View {
    /// Apply Liquid Glass to a view. On older macOS, falls back to ultra-thin material.
    /// - Parameters:
    ///   - shape: shape that masks the glass (capsule, rounded-rect, etc.)
    ///   - tint: optional brand tint (use sparingly — reserved for primary CTAs).
    ///   - interactive: when true, glass responds to hover/press with subtle illumination.
    @ViewBuilder
    func adaptiveGlass<S: Shape>(
        in shape: S,
        tint: Color? = nil,
        interactive: Bool = false
    ) -> some View {
        if #available(macOS 26.0, *) {
            // Apple's real Liquid Glass — refraction, specular, motion-aware.
            self.modifier(LiquidGlassModifier(shape: shape, tint: tint, interactive: interactive))
        } else {
            // macOS 14/15 fallback — ultra-thin material clipped to the same shape.
            self.background(
                shape.fill(.ultraThinMaterial)
                    .overlay(tint.map { shape.fill($0.opacity(0.18)) })
            )
        }
    }
}

@available(macOS 26.0, *)
private struct LiquidGlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool

    func body(content: Content) -> some View {
        // Build the Glass material with optional tint + interactive press response.
        // (Apple's API surface in macOS 26 SDK — see WWDC25 session 323.)
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return content.glassEffect(glass, in: shape)
    }
}

/// Wraps a group of glass elements so they share one refraction sampling pass
/// (and morph between each other when they animate). Apple's `GlassEffectContainer`.
/// On macOS 14/15 falls back to a plain VStack (no glass to coordinate).
struct GlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing, content: content)
        } else {
            content()
        }
    }
}
