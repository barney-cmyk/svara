import SwiftUI

struct MiniRecorderView<S: RecorderStateProvider & ObservableObject>: View {
    @ObservedObject var stateProvider: S
    @ObservedObject var recorder: Recorder
    @EnvironmentObject var windowManager: MiniWindowManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @AppStorage("showLiveTextPreview") private var showLiveTextPreview = false

    @State private var activePopover: ActivePopoverState = .none

    // MARK: - Layout Constants

    private let controlBarHeight: CGFloat = 40
    private let compactWidth: CGFloat = 184
    private let expandedWidth: CGFloat = 300
    // Bigger corners on the expanded panel for a more "liquid" flowing feel —
    // matches the Liquid Glass aesthetic of Apple's Control Center.
    private let expandedCornerRadius: CGFloat = 24

    // true when live transcript is streaming in during recording
    private var hasLiveTranscript: Bool {
        showLiveTextPreview
            && stateProvider.recordingState == .recording
            && !stateProvider.partialTranscript.isEmpty
    }

    private var controlBar: some View {
        HStack(spacing: 0) {
            RecorderPromptButton(
                activePopover: $activePopover,
                buttonSize: 22,
                padding: EdgeInsets()
            )
            .padding(.leading, 12)

            Spacer(minLength: 0)

            RecorderStatusDisplay(
                currentState: stateProvider.recordingState,
                audioMeter: recorder.audioMeter
            )

            Spacer(minLength: 0)

            RecorderPowerModeButton(
                activePopover: $activePopover,
                buttonSize: 22,
                padding: EdgeInsets()
            )
            .padding(.trailing, 12)
        }
        .frame(height: controlBarHeight)
    }

    private var transcriptSection: some View {
        VStack(spacing: 0) {
            if hasLiveTranscript {
                LiveTranscriptView(text: stateProvider.partialTranscript)
                Divider().background(Color.white.opacity(0.15))
            }
        }
    }

    var body: some View {
        if windowManager.isVisible {
            // Compact = pure capsule (Control Center pill). Expanded = larger rounded
            // rectangle so the live transcript fits without losing the liquid feel.
            // Using AnyShape so the same property holds either shape — the type
            // erasure is safe for one render pass and lets us pass into adaptiveGlass.
            let panelShape: AnyShape = hasLiveTranscript
                ? AnyShape(RoundedRectangle(cornerRadius: expandedCornerRadius, style: .continuous))
                : AnyShape(Capsule(style: .continuous))

            // GlassGroup gives child glass elements a shared sampling region — when
            // controls morph between compact/expanded states they flow into each
            // other instead of cross-fading on independent refraction surfaces.
            GlassGroup(spacing: 16) {
                VStack(spacing: 0) {
                    transcriptSection
                    controlBar
                }
                .frame(width: hasLiveTranscript ? expandedWidth : compactWidth)
                .adaptiveGlass(in: panelShape, interactive: true)
                .clipShape(panelShape)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.78), value: hasLiveTranscript)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}
