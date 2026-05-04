import SwiftUI
import SwiftData
import os

struct MetricsContent: View {
    private let logger = Logger(subsystem: "com.neuronflame.app", category: "MetricsContent")
    let modelContext: ModelContext
    let licenseState: LicenseViewModel.LicenseState

    @State private var totalCount: Int = 0
    @State private var totalWords: Int = 0
    @State private var totalDuration: TimeInterval = 0
    @State private var isLoadingMetrics: Bool = true
    @State private var metricsTask: Task<Void, Never>?
    @State private var isModelStatsPanelPresented = false
    @State private var personalRecords: PersonalRecords = .zero

    /// User's average words-per-minute over all sessions, for the You-vs-The-World card.
    private var averageWPM: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalWords) / (totalDuration / 60.0)
    }

    var body: some View {
        Group {
            if totalCount == 0 && !isLoadingMetrics {
                emptyStateView
            } else if isLoadingMetrics {
                ProgressView("Loading metrics...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Non-scrollable Dashboard built around the Ziva thesis:
                // "The moment a thought arises and you can articulate it, it's captured."
                VStack(spacing: 14) {
                    heroSection

                    // Top row: Speed-of-thought primary metric (left) + Brain→Voice→Text pulse (right)
                    HStack(alignment: .top, spacing: 14) {
                        SpeedOfThoughtCard(userWPM: averageWPM)
                        ThoughtFlowCard()
                    }

                    // Bottom row: Compare-to-world bars + Personal records
                    HStack(alignment: .top, spacing: 14) {
                        CompareToWorldCard(userWPM: averageWPM)
                        PersonalRecordsCard(records: personalRecords)
                    }

                    Spacer(minLength: 0)

                    FooterAffirmationCard()

                    // Unified bottom bar — full-width Liquid Glass strip with
                    // status pills on the left and action buttons on the right.
                    footerActionsView
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 18)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color(.windowBackgroundColor))
            }
        }
        .task {
            await loadMetricsEfficiently()
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionMetricsDidChange)) { _ in
            metricsTask?.cancel()
            metricsTask = Task {
                await loadMetricsEfficiently()
            }
        }
        .onDisappear {
            metricsTask?.cancel()
        }
        .overlay {
            Color.black.opacity(isModelStatsPanelPresented ? 0.1 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(isModelStatsPanelPresented)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.3)) { isModelStatsPanelPresented = false }
                }
                .animation(.smooth(duration: 0.3), value: isModelStatsPanelPresented)
        }
        .overlay(alignment: .trailing) {
            if isModelStatsPanelPresented {
                ModelPerformancePanel {
                    withAnimation(.smooth(duration: 0.3)) { isModelStatsPanelPresented = false }
                }
                .frame(width: 400)
                .frame(maxHeight: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color(NSColor.separatorColor)).frame(width: 1)
                }
                .shadow(color: .black.opacity(0.08), radius: 8, x: -2, y: 0)
                .ignoresSafeArea()
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.smooth(duration: 0.3), value: isModelStatsPanelPresented)
    }
    
    private func loadMetricsEfficiently() async {
        await MainActor.run {
            self.isLoadingMetrics = true
        }

        let modelContainer = modelContext.container

        let backgroundContext = ModelContext(modelContainer)

        do {
            guard !Task.isCancelled else {
                await MainActor.run {
                    self.isLoadingMetrics = false
                }
                return
            }

            let count = try backgroundContext.fetchCount(FetchDescriptor<SessionMetric>())

            guard !Task.isCancelled else {
                await MainActor.run {
                    self.isLoadingMetrics = false
                }
                return
            }

            var descriptor = FetchDescriptor<SessionMetric>()
            descriptor.propertiesToFetch = [\.wordCount, \.audioDuration, \.timestamp]

            var words = 0
            var duration: TimeInterval = 0

            // Personal records computed in the same enumeration to avoid a 2nd pass.
            var fastestWPM: Double = 0
            var fastestWPMDate: Date? = nil
            var longestSession: TimeInterval = 0
            var longestSessionDate: Date? = nil
            // Map of dayBucket(yyyy-MM-dd) -> wordCount for that day, to find best day.
            var wordsByDay: [String: Int] = [:]
            var dateForDayBucket: [String: Date] = [:]
            let bucketFmt = DateFormatter()
            bucketFmt.dateFormat = "yyyy-MM-dd"

            try backgroundContext.enumerate(descriptor) { metric in
                words += metric.wordCount
                duration += metric.audioDuration

                // Per-session WPM (skip very short sessions <2s — too noisy)
                if metric.audioDuration >= 2 && metric.wordCount > 0 {
                    let sessionWPM = Double(metric.wordCount) / (metric.audioDuration / 60.0)
                    if sessionWPM > fastestWPM {
                        fastestWPM = sessionWPM
                        fastestWPMDate = metric.timestamp
                    }
                }

                if metric.audioDuration > longestSession {
                    longestSession = metric.audioDuration
                    longestSessionDate = metric.timestamp
                }

                let bucket = bucketFmt.string(from: metric.timestamp)
                wordsByDay[bucket, default: 0] += metric.wordCount
                dateForDayBucket[bucket] = metric.timestamp
            }

            let bestDay = wordsByDay.max(by: { $0.value < $1.value })
            let mostWordsInADay = bestDay?.value ?? 0
            let mostWordsDate = bestDay.flatMap { dateForDayBucket[$0.key] }

            let computedRecords = PersonalRecords(
                fastestWPM: fastestWPM,
                fastestWPMDate: fastestWPMDate,
                longestSessionSeconds: longestSession,
                longestSessionDate: longestSessionDate,
                mostWordsInADay: mostWordsInADay,
                mostWordsDate: mostWordsDate
            )

            guard !Task.isCancelled else {
                await MainActor.run { self.isLoadingMetrics = false }
                return
            }

            await MainActor.run {
                self.totalCount = count
                self.totalWords = words
                self.totalDuration = duration
                self.personalRecords = computedRecords
                // Stay in loading state if migration is still running and no data yet —
                // sessionMetricsDidChange will trigger a reload when it finishes.
                if count > 0 || !SessionMetricMigrationService.shared.isRunning {
                    self.isLoadingMetrics = false
                }
            }
        } catch {
            logger.error("Error loading metrics: \(error.localizedDescription, privacy: .public)")
            await MainActor.run { self.isLoadingMetrics = false }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.secondary)
            Text("No Recorder Sessions Yet")
                .font(.title3.weight(.semibold))
            Text("Start your first recording to unlock value insights.")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
    
    // MARK: - Sections
    
    private var heroSection: some View {
        VStack(spacing: 6) {
            Text("Think it. It's said.")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(heroSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(heroGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 30, x: 0, y: 16)
    }
    
    private var metricsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
            MetricCard(
                icon: "mic.fill",
                title: "Sessions Recorded",
                value: "\(totalCount)",
                detail: "Neuron Flame sessions",
                color: .purple
            )

            MetricCard(
                icon: "text.alignleft",
                title: "Words Dictated",
                value: Formatters.formattedNumber(totalWords),
                detail: "words generated",
                color: Color(nsColor: .controlAccentColor)
            )
            
            MetricCard(
                icon: "speedometer",
                title: "Words Per Minute",
                value: averageWordsPerMinute > 0
                    ? String(format: "%.1f", averageWordsPerMinute)
                    : "–",
                detail: "Neuron Flame vs. typing",
                color: .yellow
            )
            
            MetricCard(
                icon: "keyboard.fill",
                title: "Keystrokes Saved",
                value: Formatters.formattedNumber(totalKeystrokesSaved),
                detail: "fewer keystrokes",
                color: .orange
            )
        }
    }

    /// Unified Liquid Glass bottom bar.
    /// Left side: live system status (mic / accessibility / hotkey) + active AI provider.
    /// Right side: action buttons (Model Performance + Copy System Info).
    /// Wrapped in a single GlassEffectContainer so refraction is shared and the
    /// pills morph cohesively when status changes.
    private var footerActionsView: some View {
        GlassGroup(spacing: 12) {
            HStack(spacing: 10) {
                // System status — pills at left
                SystemStatusBanner(compact: false)
                    .layoutPriority(1)

                Spacer(minLength: 16)

                // Action buttons — at right
                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) { isModelStatsPanelPresented = true }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gauge")
                        Text("Model Performance")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .foregroundStyle(ZivaTheme.onSurface)
                }
                .buttonStyle(.plain)
                .adaptiveGlass(in: Capsule(), interactive: true)
                .help("View transcription and enhancement model performance")

                CopySystemInfoButton()
            }
            .padding(.horizontal, 6)
        }
    }
    
    private var formattedTimeSaved: String {
        let formatted = Formatters.formattedDuration(timeSaved, style: .full, fallback: "Time savings coming soon")
        return formatted
    }
    
    private var heroSubtitle: String {
        guard totalCount > 0 else {
            return "Ziva listens at the speed of thought. Speak naturally — the page will catch up."
        }

        let wordsText = Formatters.formattedNumber(totalWords)
        // First-week vs habituated copy — gives a different reflection at different points
        if totalCount < 7 {
            return "\(wordsText) words spoken into existence."
        }
        return "\(wordsText) words this month — most of what you wrote, you said."
    }
    
    private var heroGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(nsColor: .controlAccentColor),
                Color(nsColor: .controlAccentColor).opacity(0.85),
                Color(nsColor: .controlAccentColor).opacity(0.7)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Computed Metrics

    private var estimatedTypingTime: TimeInterval {
        let averageTypingSpeed: Double = 35 // words per minute
        let estimatedTypingTimeInMinutes = Double(totalWords) / averageTypingSpeed
        return estimatedTypingTimeInMinutes * 60
    }

    private var timeSaved: TimeInterval {
        max(estimatedTypingTime - totalDuration, 0)
    }

    private var averageWordsPerMinute: Double {
        guard totalDuration > 0 else { return 0 }
        return Double(totalWords) / (totalDuration / 60.0)
    }

    private var totalKeystrokesSaved: Int {
        Int(Double(totalWords) * 5.0)
    }
    
}

private enum Formatters {
    static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    static func formattedNumber(_ value: Int) -> String {
        return numberFormatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    static func formattedDuration(_ interval: TimeInterval, style: DateComponentsFormatter.UnitsStyle, fallback: String = "–") -> String {
        guard interval > 0 else { return fallback }
        durationFormatter.unitsStyle = style
        durationFormatter.allowedUnits = interval >= 3600 ? [.hour, .minute] : [.minute, .second]
        return durationFormatter.string(from: interval) ?? fallback
    }
}

private struct CopySystemInfoButton: View {
    @State private var isCopied: Bool = false

    var body: some View {
        Button(action: {
            copySystemInfo()
        }) {
            HStack(spacing: 8) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .rotationEffect(.degrees(isCopied ? 360 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)

                Text(isCopied ? "Copied!" : "Copy System Info")
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
            }
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(.thinMaterial))
        }
        .buttonStyle(.plain)
        .scaleEffect(isCopied ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
    }

    private func copySystemInfo() {
        SystemInfoService.shared.copySystemInfoToClipboard()

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isCopied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isCopied = false
            }
        }
    }
}
