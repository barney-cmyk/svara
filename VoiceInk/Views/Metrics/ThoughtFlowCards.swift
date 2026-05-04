import SwiftUI

// MARK: - Speed of thought card (replaces the 4-card stat grid)
//
// One single emotionally-loaded number — the user's average WPM — anchored against
// the two reference points that matter: typing (~40 WPM, the bottleneck) and
// silent reading / inner thought (~250 WPM, the ceiling). The defensible numbers
// come from Brysbaert/Rayner 2019 meta-analysis (n=18,573) and Karat et al. 1999.
//
// This card replaces "Sessions Recorded / Words Dictated / WPM / Keystrokes Saved"
// because per-session counts drift toward vanity metrics. WPM is the one number
// that means "how close am I to the speed of thought?" — that's the thesis.
struct SpeedOfThoughtCard: View {
    let userWPM: Double

    private let typingWPM: Double = 40        // Average adult typing (multiple sources)
    private let thoughtWPM: Double = 250      // Silent reading / inner speech rate

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            // Big WPM display + caption
            VStack(alignment: .leading, spacing: 4) {
                Text("YOUR PACE")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)

                HStack(alignment: .lastTextBaseline, spacing: 6) {
                    Text(userWPM > 0 ? String(format: "%.0f", userWPM) : "—")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(ZivaTheme.primary)
                    Text("WPM")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant)
                        .padding(.bottom, 8)
                }

                Text(paceCommentary)
                    .font(.system(size: 13))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right side: a small tower showing where you sit between the two anchors
            speedTower
                .frame(width: 80)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    private var paceCommentary: String {
        guard userWPM > 0 else {
            return "Speak first. The number arrives after."
        }
        if userWPM >= 200 { return "Faster than most people read silently. Your hands could never." }
        if userWPM >= 150 { return "At conversational speed. Typing tops out at 40." }
        if userWPM >= 100 { return "Already over double the typing average. Closer to thinking." }
        if userWPM >= 60  { return "Past the typing average. Settling into your speaking voice." }
        return "Warming up. Speaking will outrun typing once you find your rhythm."
    }

    /// Position from top of the tower for a given WPM (thought=top, typing=bottom).
    private func yOffset(for wpm: Double, in height: CGFloat) -> CGFloat {
        let topPad: CGFloat = 4
        let usable = height - topPad * 2
        let frac = 1.0 - min(max(wpm / thoughtWPM, 0), 1.05)
        return topPad + CGFloat(frac) * usable
    }

    /// Vertical tower with three tick-marks: typing (low), you (middle, primary blue), thought (top).
    private var speedTower: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Vertical track
                Capsule()
                    .fill(ZivaTheme.surfaceContainer)
                    .frame(width: 4)
                    .offset(x: 14)

                tickMark(label: "Thought", value: "~\(Int(thoughtWPM))",
                         color: Color(red: 0.55, green: 0.55, blue: 0.65),
                         filled: false, isUser: false)
                    .offset(y: yOffset(for: thoughtWPM, in: geo.size.height) - 8)

                if userWPM > 0 {
                    tickMark(label: "You", value: "\(Int(userWPM))",
                             color: ZivaTheme.primary,
                             filled: true, isUser: true)
                        .offset(y: yOffset(for: userWPM, in: geo.size.height) - 8)
                }

                tickMark(label: "Typing", value: "~\(Int(typingWPM))",
                         color: Color(red: 0.55, green: 0.55, blue: 0.65),
                         filled: false, isUser: false)
                    .offset(y: yOffset(for: typingWPM, in: geo.size.height) - 8)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }

    private func tickMark(label: String, value: String, color: Color, filled: Bool, isUser: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(filled ? color : Color.white)
                .overlay(Circle().strokeBorder(color, lineWidth: 1.5))
                .frame(width: 12, height: 12)
                .offset(x: 10)

            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 10, weight: isUser ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isUser ? color : ZivaTheme.onSurfaceVariant)
                Text(value)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.8))
            }
            .padding(.leading, 12)
        }
    }
}

// MARK: - Thought → Voice → Text flow card
//
// The Single Pulse visualization: a horizontal flow showing brain → voice → text,
// with a continuous pulse traveling end-to-end every 2 seconds. Annotated with
// real ms latencies from the cognitive science literature so the dashboard claim
// "Ziva matches the speed of thought" is grounded in published numbers, not vibes.
//
// References:
// - Indefrey & Levelt 2004 (fMRI of word production): ~600 ms from concept to
//   articulation onset (lemma selection ~150 ms + phonological encoding ~200 ms +
//   phonetic encoding ~250 ms).
// - Whisper / Parakeet streaming ASR: ~80–150 ms first-word latency on M-series.
// - Average typing: 40 WPM ≈ 1,500 ms per word + ~600 ms thought formulation =
//   ~2,100 ms thought-to-text via keyboard.
struct ThoughtFlowCard: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/60.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let cycle = 2.0   // seconds per pulse cycle
            let progress = (t.truncatingRemainder(dividingBy: cycle)) / cycle

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("THOUGHT  →  VOICE  →  TEXT")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .tracking(0.8)
                        .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    Spacer()
                    Text("~700 ms total")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(ZivaTheme.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ZivaTheme.primaryFixed.opacity(0.6)))
                }

                flowGraphic(progress: progress)
                    .frame(maxHeight: .infinity)

                VStack(spacing: 2) {
                    Text("Speaking isn't faster than typing. It's closer to thinking.")
                        .font(.system(size: 12, design: .serif))
                        .italic()
                        .foregroundStyle(ZivaTheme.onSurface.opacity(0.75))
                    Text("Typing the same word takes ~2,100 ms (Indefrey & Levelt, 2004; 40 WPM)")
                        .font(.system(size: 10))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    colors: [ZivaTheme.primaryFixed.opacity(0.35), ZivaTheme.surfaceContainerLowest],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
            )
        }
    }

    /// Three nodes connected by a line; the line passes through the EXACT vertical
    /// center of the icon circles (not under them). Latency labels float above each
    /// segment of the line.
    private func flowGraphic(progress: Double) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Icon centers sit on the upper-third line so labels below have room
            let iconY = h * 0.42
            let labelY = h * 0.82

            let leftX: CGFloat = 30
            let midX: CGFloat = w / 2
            let rightX: CGFloat = w - 30

            // Pulse traverses left → right linearly
            let pulseX = leftX + (rightX - leftX) * progress

            ZStack {
                // Connecting line through icon centers
                Path { p in
                    p.move(to: CGPoint(x: leftX + 14, y: iconY))
                    p.addLine(to: CGPoint(x: rightX - 14, y: iconY))
                }
                .stroke(ZivaTheme.outlineVariant, lineWidth: 1.5)

                // Latency annotation: ~600 ms between Thought and Voice
                Text("~600 ms")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(ZivaTheme.surfaceContainerLowest))
                    .position(x: (leftX + midX) / 2, y: iconY - 12)

                // Latency annotation: ~100 ms between Voice and Text
                Text("~100 ms")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(ZivaTheme.surfaceContainerLowest))
                    .position(x: (midX + rightX) / 2, y: iconY - 12)

                // Trail behind the pulse (fading)
                ForEach(0..<6, id: \.self) { i in
                    let trailFraction = max(progress - Double(i) * 0.04, 0)
                    let x = leftX + (rightX - leftX) * trailFraction
                    Circle()
                        .fill(ZivaTheme.primary.opacity(0.5 - Double(i) * 0.08))
                        .frame(width: 8 - CGFloat(i), height: 8 - CGFloat(i))
                        .position(x: x, y: iconY)
                }

                // Bright pulse
                Circle()
                    .fill(ZivaTheme.primary)
                    .frame(width: 10, height: 10)
                    .position(x: pulseX, y: iconY)
                    .shadow(color: ZivaTheme.primary.opacity(0.6), radius: 6)

                // Three nodes — icon centered on iconY, label below at labelY
                nodeIcon(icon: "brain.head.profile", x: leftX, y: iconY)
                nodeIcon(icon: "waveform", x: midX, y: iconY)
                nodeIcon(icon: "text.alignleft", x: rightX, y: iconY)

                nodeLabel(text: "Thought", x: leftX, y: labelY)
                nodeLabel(text: "Voice", x: midX, y: labelY)
                nodeLabel(text: "Text", x: rightX, y: labelY)
            }
        }
    }

    private func nodeIcon(icon: String, x: CGFloat, y: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(ZivaTheme.surfaceContainerLowest)
                .overlay(Circle().strokeBorder(ZivaTheme.primary, lineWidth: 1.5))
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ZivaTheme.primary)
        }
        .position(x: x, y: y)
    }

    private func nodeLabel(text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(ZivaTheme.onSurface)
            .fixedSize()
            .position(x: x, y: y)
    }
}
