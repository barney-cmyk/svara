import SwiftUI

/// **Dynamic Island-style** notch recorder.
///
/// The pill lives at the very top of the main display, hugging the physical
/// notch silhouette on Apple Silicon laptops (and falling back to a centred
/// 180pt-wide pill on notch-less Macs / external displays). Three states:
///
/// - **`collapsed`** — invisible pill the same shape as the notch. The hardware
///   notch is what the user "sees"; the recorder is dormant.
/// - **`active`** — pill expands sideways with a spring; brand-tinted Liquid
///   Glass rim, animated audio waveform, Power Mode emoji, prompt + cancel
///   controls. This is the Apple-iPhone-Dynamic-Island feel translated to macOS.
/// - **`liveText`** — pill expands further DOWN with a live transcript panel
///   under the menu bar.
///
/// The shape is `NotchShape`, which draws outward curves at top-left and
/// top-right so the silhouette flows seamlessly into the physical hardware
/// notch (no visible seam between glass and bezel).
struct NotchRecorderView<S: RecorderStateProvider & ObservableObject>: View {
    @ObservedObject var stateProvider: S
    @ObservedObject var recorder: Recorder
    @EnvironmentObject var windowManager: NotchWindowManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @AppStorage("showLiveTextPreview") private var showLiveTextPreview = false
    @ObservedObject private var powerModeManager = PowerModeManager.shared
    @State private var activePopover: ActivePopoverState = .none

    // MARK: - Display State

    private enum DisplayState: Equatable {
        case collapsed
        case active
        case liveText
    }

    private var displayState: DisplayState {
        switch stateProvider.recordingState {
        case .recording:
            let shouldShowLive = showLiveTextPreview && !stateProvider.partialTranscript.isEmpty
            return shouldShowLive ? .liveText : .active
        case .transcribing, .enhancing:
            return .active
        default:
            return .collapsed
        }
    }

    private var isRecording: Bool {
        stateProvider.recordingState == .recording
    }

    // MARK: - Screen Geometry

    private var notchWidth: CGFloat {
        guard let screen = NSScreen.main else { return 200 }
        if let left = screen.auxiliaryTopLeftArea?.width,
           let right = screen.auxiliaryTopRightArea?.width {
            return screen.frame.width - left - right
        }
        return 200
    }

    private var notchHeight: CGFloat {
        guard let screen = NSScreen.main else { return 37 }
        if screen.safeAreaInsets.top > 0 { return screen.safeAreaInsets.top }
        return NSApplication.shared.mainMenu?.menuBarHeight ?? NSStatusBar.system.thickness
    }

    // MARK: - Layout Constants

    private let recordingSideExpansion: CGFloat = 110
    private let transcriptSideExpansion: CGFloat = 130
    private let activeHeightBonus: CGFloat = 8
    private let transcriptPanelHeight: CGFloat = 60

    private var mainRowHeight: CGFloat { notchHeight + activeHeightBonus }

    // MARK: - Pill Dimensions

    private var pillWidth: CGFloat {
        switch displayState {
        case .collapsed: return notchWidth
        case .active:    return notchWidth + recordingSideExpansion * 2
        case .liveText:  return notchWidth + transcriptSideExpansion * 2
        }
    }

    private var pillHeight: CGFloat {
        switch displayState {
        case .collapsed: return 0
        case .active:    return mainRowHeight
        case .liveText:  return mainRowHeight + transcriptPanelHeight
        }
    }

    private var sideExpansion: CGFloat {
        displayState == .liveText ? transcriptSideExpansion : recordingSideExpansion
    }

    // MARK: - Animation

    /// The signature Dynamic-Island spring — slightly bouncy on expand, smooth
    /// on collapse. Tuned to feel like Apple's hardware notch responding rather
    /// than a software UI element.
    private let expandAnimation = Animation.spring(response: 0.40, dampingFraction: 0.78)
    private let collapseAnimation = Animation.spring(response: 0.50, dampingFraction: 1.0)

    private var pillAnimation: Animation {
        displayState == .collapsed ? collapseAnimation : expandAnimation
    }

    // MARK: - Visual Constants

    /// Brand gradient that runs along the rim when recording. Reads as a
    /// subtle "the notch is alive" cue without overpowering the glass surface.
    private var rimGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.49, green: 0.23, blue: 0.93),  // brand violet
                Color(red: 0.75, green: 0.15, blue: 0.83),  // brand magenta
                Color(red: 0.98, green: 0.45, blue: 0.09)   // brand orange
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The pill's surface gradient. Black-glass when idle, slight brand wash
    /// when recording (so the user perceives the colour without the pill
    /// shouting at them).
    private var surfaceGradient: LinearGradient {
        if isRecording {
            return LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.10, green: 0.04, blue: 0.18),
                    Color.black
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color.black, Color.black],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Body

    var body: some View {
        if windowManager.isVisible {
            GeometryReader { geo in
                pill.position(x: geo.size.width / 2, y: pillHeight / 2)
            }
            .animation(pillAnimation, value: displayState)
        }
    }

    // MARK: - Pill

    /// The pill, plus its breathing halo. The halo sits as a SIBLING (not a
    /// clipped background) so it can bleed outside the notch silhouette and
    /// blur softly into the menu bar / desktop. The pill itself is a
    /// silhouette-clipped surface + rim.
    private var pill: some View {
        let shape = NotchShape(
            topCornerRadius: displayState == .liveText ? 12 : 8,
            bottomCornerRadius: displayState == .liveText ? 24 : 18
        )

        return ZStack {
            // 1. The breathing halo — drawn UNCLIPPED so it bleeds out into
            //    the surrounding real estate. Only visible while recording.
            if isRecording {
                recordingHalo
                    .frame(width: pillWidth + 40, height: pillHeight + 30)
                    .blur(radius: 22)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // 2. The clipped pill: surface gradient + brand rim + content.
            VStack(spacing: 0) {
                mainRow
                liveTextPanel
            }
            .frame(width: pillWidth, height: pillHeight)
            .background(shape.fill(surfaceGradient))
            .overlay(
                // Brand-gradient rim that traces the silhouette while recording.
                shape
                    .stroke(rimGradient, lineWidth: 1.4)
                    .opacity(isRecording ? 0.9 : 0)
                    .animation(.easeInOut(duration: 0.35), value: isRecording)
            )
            .overlay(
                // Constant hairline that defines the silhouette against the
                // menu bar even when idle/transcribing. (NotchShape isn't
                // InsettableShape so we use .stroke, not .strokeBorder.)
                shape
                    .stroke(Color.white.opacity(0.07), lineWidth: 0.6)
            )
            .clipShape(shape)
        }
        .animation(.easeInOut(duration: 0.4), value: isRecording)
    }

    /// Pulsing brand-tinted halo. Sits behind the pill and blurs out so the
    /// edges feather into the menu bar / desktop wallpaper. A subtle
    /// breathing animation when recording — barely perceptible but adds life.
    private var recordingHalo: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let breath = (sin(t * 1.6) + 1) / 2  // 0…1 oscillation, ~3.9s period

            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(rimGradient)
                .opacity(0.25 + breath * 0.20)
        }
    }

    // MARK: - Main Row

    private var mainRow: some View {
        ZStack {
            Color.clear

            // Left side — prompt + power-mode controls
            HStack(spacing: 10) {
                RecorderPromptButton(activePopover: $activePopover, buttonSize: 20, padding: EdgeInsets())
                RecorderPowerModeButton(activePopover: $activePopover, buttonSize: 20, padding: EdgeInsets())
                Spacer(minLength: 0)
            }
            .padding(.leading, displayState == .liveText ? 18 : 14)
            .frame(width: sideExpansion)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(displayState != .collapsed ? 1 : 0)
            .animation(
                displayState != .collapsed ? expandAnimation.delay(0.09) : collapseAnimation,
                value: displayState
            )

            // Right side — audio meter / processing indicator
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                RecorderStatusDisplay(
                    currentState: stateProvider.recordingState,
                    audioMeter: recorder.audioMeter,
                    menuBarHeight: notchHeight
                )
            }
            .padding(.trailing, displayState == .liveText ? 18 : 14)
            .frame(width: sideExpansion)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(displayState != .collapsed ? 1 : 0)
            .animation(
                displayState != .collapsed ? expandAnimation.delay(0.09) : collapseAnimation,
                value: displayState
            )
        }
        .frame(height: mainRowHeight)
    }

    // MARK: - Live Text Panel

    private var liveTextPanel: some View {
        VStack(spacing: 0) {
            if displayState == .liveText {
                Divider()
                    .background(Color.white.opacity(0.10))
                LiveTranscriptView(text: stateProvider.partialTranscript)
                    .padding(.horizontal, 10)
            }
        }
        .frame(height: displayState == .liveText ? transcriptPanelHeight : 0)
        .clipped()
    }
}
