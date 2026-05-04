import SwiftUI

/// A reusable info tip component that displays embedded help in a popover.
///
/// Self-contained: all help text is embedded in the app. We deliberately do NOT
/// open external documentation links anymore — every feature should explain
/// itself inline. The legacy `learnMoreURL:` initializer is kept for source
/// compatibility but the URL parameter is ignored; richer help should be passed
/// as part of the `message` instead.
struct InfoTip: View {
    var message: String
    var iconName: String = "info.circle.fill"
    var iconSize: Image.Scale = .medium
    var iconColor: Color = .primary
    var width: CGFloat = 320
    @State private var isShowingTip: Bool = false

    var body: some View {
        Image(systemName: iconName)
            .imageScale(iconSize)
            .foregroundColor(iconColor)
            .fontWeight(.semibold)
            .padding(5)
            .contentShape(Rectangle())
            .popover(isPresented: $isShowingTip) {
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: width, alignment: .leading)
                    .padding(14)
            }
            .onTapGesture { isShowingTip.toggle() }
    }
}

// MARK: - Convenience initializers

extension InfoTip {
    /// Creates an InfoTip with just a message.
    init(_ message: String) {
        self.message = message
    }

    /// Compatibility init — `learnMoreURL` is intentionally ignored.
    /// Existing callers that previously linked out to docs keep compiling, but
    /// no external URL is ever opened. Migrate them to embed richer help text
    /// directly into the message.
    init(_ message: String, learnMoreURL: String) {
        self.message = message
    }
}
