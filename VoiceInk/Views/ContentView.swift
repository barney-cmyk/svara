import SwiftUI
import SwiftData
import KeyboardShortcuts
import OSLog
import Sparkle

// ViewType enum with all cases
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "Dashboard"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case models = "AI Models"
    case enhancement = "Enhancement"
    case powerMode = "Power Mode"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case dictionary = "Dictionary"
    case settings = "Settings"
    case license = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .metrics: return "gauge.medium"
        case .transcribeAudio: return "waveform.circle.fill"
        case .history: return "doc.text.fill"
        case .models: return "brain.head.profile"
        case .enhancement: return "wand.and.stars"
        case .powerMode: return "sparkles.square.fill.on.square"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        case .license: return "heart.fill"
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    private let logger = Logger(subsystem: "com.neuronflame.app", category: "ContentView")
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var engine: ZivaEngine
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @State private var hasKickedOffLaunchUpdateCheck = false
    @AppStorage("powerModeUIFlag") private var powerModeUIFlag = false
    @State private var selectedView: ViewType? = .metrics
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @StateObject private var licenseViewModel = LicenseViewModel()

    private var visibleViewTypes: [ViewType] {
        ViewType.allCases.filter { viewType in
            if viewType == .powerMode {
                return powerModeUIFlag
            }
            return true
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section {
                    // App Header — icon + wordmark, with a quietly-appearing
                    // "Update available" pill underneath when Sparkle's
                    // background check finds a newer version. The pill is
                    // tappable and triggers the standard install dialog.
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            if let appIcon = NSImage(named: "AppIcon") {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(8)
                            }

                            Text("Neuron Flame")
                                .font(.system(size: 14, weight: .semibold))
                                .lineLimit(1)
                                .truncationMode(.tail)

                            Spacer(minLength: 0)
                        }

                        SidebarUpdatePill()
                    }
                    .padding(.vertical, 4)
                }

                // Live system status — pills live in the sidebar so they're
                // visible from any tab (not just Dashboard). Compact mode stacks
                // them vertically to fit the 210pt column.
                Section {
                    SystemStatusBanner(compact: true)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }

                ForEach(visibleViewTypes) { viewType in
                    Section {
                        NavigationLink(value: viewType) {
                            SidebarItemView(viewType: viewType)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                }

                // Sidebar utilities — moved here from the Dashboard's bottom bar
                // to free up vertical real estate for the metric cards. The
                // Model Performance button posts a notification that
                // MetricsContent listens for, so the panel still slides in
                // from the Dashboard pane regardless of where the button lives.
                Section {
                    SidebarUtilityButton(
                        icon: "gauge",
                        label: "Model Performance",
                        help: "View transcription and enhancement model performance"
                    ) {
                        NotificationCenter.default.post(
                            name: .openModelPerformancePanel,
                            object: nil
                        )
                        selectedView = .metrics
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                    SidebarCopySystemInfoButton()
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Neuron Flame")
            .navigationSplitViewColumnWidth(210)
        } detail: {
            if let selectedView = selectedView {
                detailView(for: selectedView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(selectedView.rawValue)
            } else {
                Text("Select a view")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 950)
        .frame(minHeight: 730)
        .onAppear {
            logger.notice("ContentView appeared")
            // Kick off two background checks shortly after launch:
            //
            // 1. Sparkle silent update check → if a newer Neuron Flame is
            //    available, UpdaterViewModel sets availableUpdate and the
            //    SidebarUpdatePill fades in.
            //
            // 2. RemoteModelCatalogue refresh → pulls the latest models.json
            //    from neuronflame.com so users see new/updated transcription
            //    models (Distil-Whisper, new Parakeet variants, etc.) in the
            //    AI Models tab without needing an app update.
            //
            // 8s delay so model prewarm + first-paint aren't competing with
            // outbound network. Subsequent ticks are scheduled per-service.
            if !hasKickedOffLaunchUpdateCheck {
                hasKickedOffLaunchUpdateCheck = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    updaterViewModel.silentlyCheckForUpdates()
                    Task { @MainActor in
                        await RemoteModelCatalogue.shared.refresh()
                        // After the remote list lands, ask the transcription
                        // model manager to re-derive its available models so
                        // any new entries show up in the AI Models tab
                        // without a restart.
                        transcriptionModelManager.refreshAllAvailableModels()
                    }
                }

                // Schedule a second refresh every 24h while the app stays
                // open. Sparkle already does its own scheduling for the
                // update channel; we add the model channel here.
                Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { _ in
                    Task { @MainActor in
                        await RemoteModelCatalogue.shared.refresh()
                        transcriptionModelManager.refreshAllAvailableModels()
                    }
                }
            }
        }
        .onDisappear {
            logger.notice("ContentView disappeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            if let destination = notification.userInfo?["destination"] as? String {
                logger.notice("navigateToDestination received: \(destination, privacy: .public)")
                switch destination {
                case "Settings":
                    selectedView = .settings
                case "AI Models":
                    selectedView = .models
                case "About", "Pro":
                    selectedView = .license
                case "History":
                    selectedView = .history
                case "Permissions":
                    selectedView = .permissions
                case "Enhancement":
                    selectedView = .enhancement
                case "Transcribe Audio":
                    selectedView = .transcribeAudio
                case "Power Mode":
                    selectedView = .powerMode
                default:
                    break
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .metrics:
            MetricsView()
        case .models:
            ModelManagementView()
        case .enhancement:
            EnhancementSettingsView()
        case .transcribeAudio:
            AudioTranscribeView()
        case .history:
            InlineHistoryView()
        case .audioInput:
            AudioInputSettingsView()
        case .dictionary:
            DictionarySettingsView(whisperPrompt: whisperModelManager.whisperPrompt)
        case .powerMode:
            PowerModeView()
        case .settings:
            SettingsView()
        case .license:
            LicenseManagementView()
        case .permissions:
            PermissionsView()
        }
    }
}

private struct SidebarItemView: View {
    let viewType: ViewType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewType.icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24, height: 24)

            Text(viewType.rawValue)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }
}

/// Generic Liquid-Glass utility button for the sidebar's bottom section.
/// Looks like the nav rows but is wrapped in glass to read as an action,
/// not a tab.
private struct SidebarUtilityButton: View {
    let icon: String
    let label: String
    let help: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(ZivaTheme.primary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZivaTheme.onSurface)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .adaptiveGlass(in: Capsule(), interactive: true)
        .overlay(
            Capsule().strokeBorder(ZivaTheme.outlineVariant.opacity(0.4), lineWidth: 0.5)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .help(help)
        .padding(.horizontal, 4)
    }
}

/// Sidebar variant of Copy System Info — same behaviour as the dashboard
/// version, sized for the 210pt sidebar column with a Liquid-Glass capsule.
private struct SidebarCopySystemInfoButton: View {
    @State private var isCopied: Bool = false
    @State private var isHovered = false

    var body: some View {
        Button(action: copy) {
            HStack(spacing: 10) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                    .foregroundStyle(isCopied
                        ? Color(red: 0.13, green: 0.55, blue: 0.27)
                        : ZivaTheme.primary)
                    .contentTransition(.symbolEffect(.replace))
                Text(isCopied ? "Copied!" : "Copy System Info")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ZivaTheme.onSurface)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .adaptiveGlass(in: Capsule(), interactive: true)
        .overlay(
            Capsule().strokeBorder(ZivaTheme.outlineVariant.opacity(0.4), lineWidth: 0.5)
        )
        .scaleEffect(isCopied ? 1.04 : (isHovered ? 1.02 : 1.0))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCopied)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { isHovered = $0 }
        .help("Copy diagnostic info to share when reporting an issue")
        .padding(.horizontal, 4)
    }

    private func copy() {
        SystemInfoService.shared.copySystemInfoToClipboard()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isCopied = false }
        }
    }
}

// MARK: - Sidebar update pill
//
// Appears under the brand mark when Sparkle's background check finds a new
// version. Hidden completely when up-to-date — no permanent "version" badge,
// no nag. Click → opens the standard install dialog.
//
// The animation: pill slides + fades in from above. A small pulsing brand-orange
// dot draws attention without being aggressive.
private struct SidebarUpdatePill: View {
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @State private var pulse = false
    @State private var hovered = false

    var body: some View {
        Group {
            if let update = updaterViewModel.availableUpdate {
                Button {
                    // Trigger the standard "An update is available" dialog so
                    // the user sees release notes + Install / Skip buttons.
                    updaterViewModel.checkForUpdates()
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(ZivaTheme.primary)
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulse ? 1.4 : 1.0)
                            .opacity(pulse ? 0.6 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.1).repeatForever(autoreverses: true),
                                value: pulse
                            )

                        Text("v\(update.displayVersionString) ready")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(ZivaTheme.primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ZivaTheme.primary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .fill(ZivaTheme.primaryFixed.opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 999, style: .continuous)
                            .strokeBorder(ZivaTheme.primary.opacity(0.3), lineWidth: 1)
                    )
                    .scaleEffect(hovered ? 1.02 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hovered)
                }
                .buttonStyle(.plain)
                .onHover { hovered = $0 }
                .help("New version v\(update.displayVersionString) is available — click to install")
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    )
                )
                .onAppear { pulse = true }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: updaterViewModel.availableUpdate?.displayVersionString)
    }
}

