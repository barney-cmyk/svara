import SwiftUI
import KeyboardShortcuts

struct EnhancementShortcutsView: View {
    var body: some View {
        VStack(spacing: 8) {
            // Toggle AI Enhancement
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 4) {
                    Text("Toggle AI Enhancement")
                        .font(.system(size: 13))

                    InfoTip(
                        "Toggle AI enhancement on or off mid-recording with a keyboard shortcut. Useful when you want a verbatim quote (enhancement off) inside an otherwise-polished session, or vice versa. The shortcut only fires while the floating recorder panel is visible — outside of recording it's inactive so it can't conflict with your other apps. Configure the keystroke by clicking the field and pressing the keys you want.",
                        learnMoreURL: "https://neuronflame.com/docs/shortcuts.html"
                    )
                }

                Spacer()

                KeyboardShortcuts.Recorder(for: .toggleEnhancement)
                    .controlSize(.small)
            }

            // Switch Enhancement Prompt
            HStack(alignment: .center, spacing: 12) {
                HStack(spacing: 4) {
                    Text("Switch Enhancement Prompt")
                        .font(.system(size: 13))

                    InfoTip(
                        "Press ⌘1 through ⌘0 while the recorder is open to switch between your saved prompts in order. ⌘1 selects the first prompt in your Enhancement list, ⌘2 the second, and so on; ⌘0 selects the tenth. The active prompt determines how the transcript is post-processed. Useful when you frequently bounce between styles — e.g. ⌘1 for chat, ⌘2 for email, ⌘3 for verbatim. The shortcut is inert when the recorder isn't visible, so it won't intercept your other apps.",
                        learnMoreURL: "https://neuronflame.com/docs/shortcuts.html"
                    )
                }

                Spacer()

                HStack(spacing: 4) {
                    KeyChip(label: "⌘")
                    KeyChip(label: "1 – 0")
                }
            }
        }
        .background(Color.clear)
    }
}

// MARK: - Supporting Views
private struct KeyChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(
                        Color(NSColor.separatorColor).opacity(0.5),
                        lineWidth: 0.5
                    )
            )
    }
}
