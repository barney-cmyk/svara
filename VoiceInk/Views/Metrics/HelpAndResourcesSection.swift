import SwiftUI

/// Compact "Feedback & Issues" card. Replaces the original multi-link Help & Resources section
/// since this build is for personal/family distribution, not a public product.
struct HelpAndResourcesSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Feedback & Issues")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary.opacity(0.85))

            Button {
                let mailto = "mailto:barney@theaussiesharmas.com.au?subject=Ziva%20AI%20feedback"
                if let url = URL(string: mailto) {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.accentColor)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Send Feedback or Report an Issue")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Goes straight to Barney — replies in plain English.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
