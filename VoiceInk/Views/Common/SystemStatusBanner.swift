import SwiftUI
import AVFoundation
import KeyboardShortcuts

/// Live system-status banner shown at the top of the Dashboard.
/// Polls the same permission checks the Permissions tab uses, every 3 seconds,
/// and on app activation. Click to expand and see per-item status + fix buttons.
struct SystemStatusBanner: View {
    @StateObject private var permissions = PermissionManager()
    @ObservedObject private var deviceManager = AudioDeviceManager.shared
    @EnvironmentObject private var aiService: AIService
    @State private var isExpanded = false
    @State private var refreshTimer: Timer?

    /// When true, renders in a narrow vertical layout suited for the sidebar
    /// (pills stacked, smaller fonts). Default false = horizontal dashboard layout.
    var compact: Bool = false

    private var isMicOK: Bool       { permissions.audioPermissionStatus == .authorized }
    private var isAxOK: Bool        { permissions.isAccessibilityEnabled }
    private var isHotkeyOK: Bool    { permissions.isKeyboardShortcutSet }
    private var isScreenOK: Bool    { permissions.isScreenRecordingEnabled }
    // Required permissions — count toward "All systems go" / issue count
    private var allOK: Bool         { isMicOK && isAxOK && isHotkeyOK }
    private var issueCount: Int     { [isMicOK, isAxOK, isHotkeyOK].filter { !$0 }.count }

    /// AI provider connection — only show "Powered by X" when a key has been entered AND validated.
    private var isAIConnected: Bool {
        aiService.isAPIKeyValid && !aiService.apiKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var statusColor: Color  { allOK ? Color(red: 0.13, green: 0.55, blue: 0.27) : Color(red: 0.85, green: 0.45, blue: 0.05) }
    private var statusBg:    Color  { allOK ? Color(red: 0.85, green: 0.95, blue: 0.87) : Color(red: 1.00, green: 0.94, blue: 0.84) }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 10) {
            // Compact (sidebar) stacks pills vertically; non-compact (dashboard) keeps them on one row
            if compact {
                pill
                if isAIConnected { aiProviderPill }
            } else {
                HStack(spacing: 10) {
                    pill
                    if isAIConnected { aiProviderPill }
                }
            }
            if let qualityWarning = deviceManager.inputQualityWarning {
                qualityPill(qualityWarning)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            if isExpanded {
                detailRows
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            permissions.checkAllPermissions()
            deviceManager.refreshInputQualityWarning()
            refreshTimer?.invalidate()
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                permissions.checkAllPermissions()
                AudioDeviceManager.shared.refreshInputQualityWarning()
            }
        }
        .onDisappear { refreshTimer?.invalidate() }
    }

    // MARK: - Pill

    private var pill: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.25))
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)
            }

            Text(allOK ? "All systems go" : "\(issueCount) issue\(issueCount == 1 ? "" : "s") — tap to fix")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor)

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(statusColor.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(statusBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(statusColor.opacity(0.3), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        }
    }

    // MARK: - Input quality pill

    /// Orange advisory shown when the active mic is a Bluetooth device stuck
    /// in low-bandwidth call mode (e.g. AirPods at 16 kHz). Not counted as an
    /// "issue" — recording still works, quality is just degraded.
    private func qualityPill(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "airpods")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.05))

            Text(message)
                .font(.system(size: compact ? 11 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.85, green: 0.45, blue: 0.05))
                .lineLimit(compact ? 3 : 2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 1.00, green: 0.94, blue: 0.84))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(red: 0.85, green: 0.45, blue: 0.05).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - AI provider pill

    private var aiProviderPill: some View {
        // Compact (sidebar) shows just the provider + Live dot to avoid clipping
        // in the narrow 210pt column. Full (dashboard) shows the longer label.
        HStack(spacing: compact ? 6 : 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(ZivaTheme.primary)

            Text(compact ? aiService.selectedProvider.rawValue : "Powered by \(aiService.selectedProvider.rawValue)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(ZivaTheme.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Circle()
                .fill(Color(red: 0.13, green: 0.55, blue: 0.27))
                .frame(width: 7, height: 7)

            Text("Live")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.13, green: 0.55, blue: 0.27))
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 10)
        .frame(maxWidth: compact ? .infinity : nil, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(ZivaTheme.primaryFixed.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ZivaTheme.primary.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Detail rows

    private var detailRows: some View {
        VStack(spacing: 8) {
            statusRow(
                title: "Microphone",
                subtitle: "Required to record your voice",
                ok: isMicOK,
                fix: openMicSettings
            )
            statusRow(
                title: "Accessibility",
                subtitle: "Required to paste text at the cursor",
                ok: isAxOK,
                fix: openAccessibilitySettings
            )
            statusRow(
                title: "Dictation hotkey",
                subtitle: "Required to start a recording",
                ok: isHotkeyOK,
                fix: openHotkeySettings
            )
            optionalRow(
                title: "Screen Recording",
                subtitle: "Optional — only needed for Power Mode (app-aware transcription)",
                ok: isScreenOK,
                fix: openScreenRecordingSettings
            )
        }
    }

    private func statusRow(title: String, subtitle: String, ok: Bool, fix: @escaping () -> Void) -> some View {
        // Compact single-line rows so the expanded banner doesn't push dashboard
        // content off-screen. Subtitle is shown only when status is bad (where the
        // user actually needs context to act). When OK, just title + checkmark + badge.
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 15))
                .foregroundStyle(ok ? Color(red: 0.13, green: 0.55, blue: 0.27) : Color(red: 0.85, green: 0.45, blue: 0.05))

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ZivaTheme.onSurface)

            if !ok {
                Text("· \(subtitle)")
                    .font(.system(size: 11))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            if !ok {
                Button { fix() } label: {
                    Text("Fix")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(ZivaTheme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Text("OK")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.55, blue: 0.27))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.95, blue: 0.87)))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    /// Same as statusRow but visually communicates "optional".
    /// When NOT granted: subdued gray icon + "Enable" button (not orange "Fix").
    /// When granted: same green OK pill as required rows.
    private func optionalRow(title: String, subtitle: String, ok: Bool, fix: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "minus.circle")
                .font(.system(size: 15))
                .foregroundStyle(ok ? Color(red: 0.13, green: 0.55, blue: 0.27) : Color.secondary.opacity(0.6))

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ZivaTheme.onSurface)

            if !ok {
                Text("· \(subtitle)")
                    .font(.system(size: 11))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .lineLimit(1)
            }

            Spacer()

            if ok {
                Text("OK")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.13, green: 0.55, blue: 0.27))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(red: 0.85, green: 0.95, blue: 0.87)))
            } else {
                Button { fix() } label: {
                    Text("Enable")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .foregroundStyle(ZivaTheme.primary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openMicSettings() {
        if permissions.audioPermissionStatus == .notDetermined {
            permissions.requestAudioPermission()
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openHotkeySettings() {
        NotificationCenter.default.post(
            name: .navigateToDestination,
            object: nil,
            userInfo: ["destination": "Settings"]
        )
    }

    private func openScreenRecordingSettings() {
        // macOS only registers an app in the Screen Recording list if it has *actually*
        // attempted a screen capture. Calling CGRequestScreenCaptureAccess() alone is
        // unreliable on recent macOS — it only triggers registration when paired with
        // a real CGWindowListCreateImage call. Do that first, ignore the result, then
        // request + open System Settings so the user sees a populated list.
        _ = CGWindowListCreateImage(.zero, .optionAll, kCGNullWindowID, [.nominalResolution])
        permissions.requestScreenRecordingPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
