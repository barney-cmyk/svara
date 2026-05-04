import SwiftUI

/// Phase 1 of the gamification dashboard: 3 emotionally-resonant cards that
/// celebrate the user's dictation without falling into anti-patterns
/// (no leaderboards, no streak shame, no composite "score" numbers).

// MARK: - Personal records data
/// Aggregated personal-best stats computed once from SessionMetric history.
struct PersonalRecords {
    var fastestWPM: Double
    var fastestWPMDate: Date?
    var longestSessionSeconds: TimeInterval
    var longestSessionDate: Date?
    var mostWordsInADay: Int
    var mostWordsDate: Date?

    static let zero = PersonalRecords(
        fastestWPM: 0, fastestWPMDate: nil,
        longestSessionSeconds: 0, longestSessionDate: nil,
        mostWordsInADay: 0, mostWordsDate: nil
    )
}

// MARK: - Compare to the world

/// Horizontal bar chart placing the user's WPM against two famous anchors:
/// average typist (40 WPM, Dhakal et al. 2018) and Barbara Blackburn's
/// world-record sustained typing speed (212 WPM, Dvorak keyboard).
struct CompareToWorldCard: View {
    let userWPM: Double

    // Reference benchmarks — verified, real numbers (see proposal doc).
    private let avgTypistWPM: Double = 40
    private let worldRecordWPM: Double = 212

    private var maxWPM: Double { max(userWPM, worldRecordWPM) * 1.05 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Text("YOU vs THE WORLD")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                Spacer()
                Text("Words per minute")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
            }

            VStack(spacing: 14) {
                bar(
                    label: "You",
                    value: userWPM,
                    color: ZivaTheme.primary,
                    isUser: true,
                    annotation: userWPM > 0 ? "your average" : "no sessions yet"
                )
                bar(
                    label: "Average typist",
                    value: avgTypistWPM,
                    color: Color(red: 0.6, green: 0.6, blue: 0.7),
                    isUser: false,
                    annotation: "Dhakal et al., 2018 (n=168k)"
                )
                bar(
                    label: "World record",
                    value: worldRecordWPM,
                    color: Color(red: 0.85, green: 0.55, blue: 0.05),
                    isUser: false,
                    annotation: "Barbara Blackburn, sustained on Dvorak"
                )
            }
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

    private func bar(label: String, value: Double, color: Color, isUser: Bool, annotation: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .lastTextBaseline) {
                Text(label)
                    .font(.system(size: 13, weight: isUser ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurface)
                Spacer()
                Text(value > 0 ? "\(Int(value.rounded())) WPM" : "—")
                    .font(.system(size: 13, weight: isUser ? .bold : .medium, design: .rounded))
                    .foregroundStyle(isUser ? color : ZivaTheme.onSurfaceVariant)
            }

            GeometryReader { geo in
                let fraction = maxWPM > 0 ? CGFloat(value / maxWPM) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(ZivaTheme.surfaceContainer)
                    Capsule()
                        .fill(color.opacity(isUser ? 1.0 : 0.55))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 10)

            Text(annotation)
                .font(.system(size: 10))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
        }
    }
}

// MARK: - Personal records

/// Three personal-best rows stacked vertically — each row is icon + value + label + date.
/// Stacking horizontally (rows) instead of in 3 cramped columns gives labels room to breathe.
struct PersonalRecordsCard: View {
    let records: PersonalRecords

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERSONAL RECORDS")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(ZivaTheme.onSurfaceVariant)

            VStack(spacing: 8) {
                row(
                    icon: "bolt.fill",
                    iconColor: Color(red: 0.85, green: 0.55, blue: 0.05),
                    iconBg: Color(red: 1.00, green: 0.95, blue: 0.85),
                    value: records.fastestWPM > 0 ? "\(Int(records.fastestWPM.rounded()))" : "—",
                    unit: "WPM",
                    label: "Fastest pace",
                    when: records.fastestWPMDate
                )
                row(
                    icon: "timer",
                    iconColor: ZivaTheme.primary,
                    iconBg: ZivaTheme.primaryFixed,
                    value: records.longestSessionSeconds > 0 ? formatDuration(records.longestSessionSeconds) : "—",
                    unit: "",
                    label: "Longest session",
                    when: records.longestSessionDate
                )
                row(
                    icon: "text.alignleft",
                    iconColor: Color(red: 0.13, green: 0.55, blue: 0.27),
                    iconBg: Color(red: 0.85, green: 0.95, blue: 0.87),
                    value: records.mostWordsInADay > 0 ? "\(records.mostWordsInADay)" : "—",
                    unit: "words",
                    label: "Best day",
                    when: records.mostWordsDate
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .adaptiveGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    /// Single horizontal row: icon · big value · unit · (label + when date).
    private func row(icon: String, iconColor: Color, iconBg: Color,
                     value: String, unit: String, label: String,
                     when: Date?) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 30, height: 30)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurface)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant)
                }
            }
            .frame(width: 90, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ZivaTheme.onSurface.opacity(0.85))
                if let when = when {
                    Text(formatRelativeDate(when))
                        .font(.system(size: 10))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ZivaTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // Deprecated tile renderer kept here only because the original 3-column layout
    // referenced it; safe to remove if no other callers.
    private func tile(icon: String, iconColor: Color, iconBg: Color,
                      value: String, unit: String, label: String,
                      when: Date?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous).fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 30, height: 30)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurface)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant)
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                if let when = when {
                    Text(formatRelativeDate(when))
                        .font(.system(size: 10))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.7))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZivaTheme.surfaceContainerLow)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins == 0 { return "\(secs)s" }
        if secs == 0 { return "\(mins)m" }
        return "\(mins)m \(secs)s"
    }

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Footer affirmation

/// Single rotating italicized line at the bottom of the dashboard. Deliberately
/// simple and warm. Not gamified, no badges, no notifications.
struct FooterAffirmationCard: View {
    private static let lines: [String] = [
        "The thought you just had is now somewhere you can find it.",
        "Nothing was lost in translation today.",
        "You wrote a small book this week. You just didn't type it.",
        "Your hands rested. Your ideas didn't.",
        "Speed of thought is a real measurement now.",
        "Every sentence here started as something only you could say.",
        "The cursor used to wait for you. Today it kept up.",
        "Most of this would have stayed in your head a year ago.",
        "You are not behind on anything you've already spoken.",
        "Ziva is listening. That's the whole feature."
    ]

    /// Stable line for the day (changes once per calendar day, not per render).
    private var todaysLine: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
        return Self.lines[dayOfYear % Self.lines.count]
    }

    var body: some View {
        Text(todaysLine)
            .font(.system(size: 13, design: .serif))
            .italic()
            .foregroundStyle(ZivaTheme.onSurfaceVariant)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
    }
}
