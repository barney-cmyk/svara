import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum ModelFilter: String, CaseIterable, Identifiable {
    case recommended = "Recommended"
    case local = "Local"
    case cloud = "Cloud"
    case custom = "Custom"
    var id: String { self.rawValue }
}

struct ModelManagementView: View {
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @EnvironmentObject private var fluidAudioModelManager: FluidAudioModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @State private var customModelToEdit: CustomCloudModel?
    @StateObject private var aiService = AIService()
    @StateObject private var customModelManager = CustomCloudModelManager.shared
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var whisperPrompt = WhisperPrompt()
    @ObservedObject private var warmupCoordinator = WhisperModelWarmupCoordinator.shared

    @State private var selectedFilter: ModelFilter = .recommended
    @State private var isShowingSettings = false

    // Sub-filters that only apply on the Local tab. Multi-select chips —
    // empty set means "show everything". Trust filters by ModelMetadata.Trust,
    // Org filters by the first segment of the origin string ("OpenAI",
    // "NVIDIA", etc.), Family filters by ModelMetadata.family().
    @State private var trustFilters: Set<ModelMetadata.Trust> = []
    @State private var orgFilters: Set<String> = []
    @State private var familyFilters: Set<String> = []
    @State private var isLocalFilterBarExpanded = false

    private let settingsPanelWidth: CGFloat = 400

    // State for the unified alert
    @State private var isShowingDeleteAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var deleteActionClosure: () -> Void = {}

    private func closeSettings() {
        withAnimation(.smooth(duration: 0.3)) {
            isShowingSettings = false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if SystemArchitecture.isIntelMac {
                    intelMacWarningBanner
                }

                defaultModelSection
                languageSelectionSection
                availableModelsSection
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .slidingPanel(isPresented: $isShowingSettings, width: settingsPanelWidth) {
            settingsPanelContent
        }
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text("Delete"), action: deleteActionClosure),
                secondaryButton: .cancel()
            )
        }
    }

    private var settingsPanelContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Model Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { closeSettings() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Divider().opacity(0.5), alignment: .bottom
            )

            // Content
            ModelSettingsView(whisperPrompt: whisperPrompt)
        }
    }
    
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(transcriptionModelManager.currentTranscriptionModel?.displayName ?? "No model selected")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }

    private var languageSelectionSection: some View {
        LanguageSelectionView(transcriptionModelManager: transcriptionModelManager, displayMode: .full, whisperPrompt: whisperPrompt)
    }
    
    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                // Modern compact pill switcher
                HStack(spacing: 12) {
                    ForEach(ModelFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFilter = filter
                                isShowingSettings = false
                            }
                        }) {
                            Text(filter.rawValue)
                                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .medium))
                                .foregroundColor(selectedFilter == filter ? .primary : .primary.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    CardBackground(isSelected: selectedFilter == filter, cornerRadius: 22)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) {
                        isShowingSettings.toggle()
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isShowingSettings ? .accentColor : .primary.opacity(0.7))
                        .padding(12)
                        .background(
                            CardBackground(isSelected: isShowingSettings, cornerRadius: 22)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 12)

            // Filter chips — only shown on the Local tab. Lets the user
            // narrow by trust level, organisation, or family. Empty
            // selections in a group mean "include all".
            if selectedFilter == .local {
                LocalFilterBar(
                    availableTrusts: availableTrustsInLocalSet,
                    availableOrgs: availableOrgsInLocalSet,
                    availableFamilies: availableFamiliesInLocalSet,
                    selectedTrusts: $trustFilters,
                    selectedOrgs: $orgFilters,
                    selectedFamilies: $familyFilters,
                    isExpanded: $isLocalFilterBarExpanded
                )
                .padding(.bottom, 8)
            }

            VStack(spacing: 12) {
                    ForEach(filteredModels, id: \.id) { model in
                        let isWarming = (model as? WhisperModel).map { whisperModel in
                            warmupCoordinator.isWarming(modelNamed: whisperModel.name)
                        } ?? false

                        // On the Recommended tab, prefix each row with a
                        // small colour-coded badge explaining why the engine
                        // picked it. Each category has its own gradient so
                        // users can scan the column and immediately see what
                        // each pick optimises for (speed = orange, accuracy
                        // = green, multilingual = blue, etc).
                        if selectedFilter == .recommended,
                           let reason = recommendationReason(for: model) {
                            ReasonBadge(reason: reason)
                                .padding(.leading, 4)
                                .padding(.top, 4)
                                .padding(.bottom, -4)
                        }

                        ModelCardView(
                            model: model,
                            fluidAudioModelManager: fluidAudioModelManager,
                            transcriptionModelManager: transcriptionModelManager,
                            isDownloaded: whisperModelManager.availableModels.contains { $0.name == model.name },
                            isCurrent: transcriptionModelManager.currentTranscriptionModel?.name == model.name,
                            downloadProgress: whisperModelManager.downloadProgress,
                            modelURL: whisperModelManager.availableModels.first { $0.name == model.name }?.url,
                            isWarming: isWarming,
                            deleteAction: {
                                if let customModel = model as? CustomCloudModel {
                                    alertTitle = "Delete Custom Model"
                                    alertMessage = "Are you sure you want to delete the custom model '\(customModel.displayName)'?"
                                    deleteActionClosure = {
                                        customModelManager.removeCustomModel(withId: customModel.id)
                                        transcriptionModelManager.refreshAllAvailableModels()
                                    }
                                    isShowingDeleteAlert = true
                                } else if let downloadedModel = whisperModelManager.availableModels.first(where: { $0.name == model.name }) {
                                    alertTitle = "Delete Model"
                                    alertMessage = "Are you sure you want to delete the model '\(downloadedModel.name)'?"
                                    deleteActionClosure = {
                                        Task {
                                            await whisperModelManager.deleteModel(downloadedModel)
                                        }
                                    }
                                    isShowingDeleteAlert = true
                                }
                            },
                            setDefaultAction: {
                                Task {
                                    transcriptionModelManager.setDefaultTranscriptionModel(model)
                                }
                            },
                            downloadAction: {
                                if let whisperModel = model as? WhisperModel {
                                    Task { await whisperModelManager.downloadModel(whisperModel) }
                                }
                            },
                            editAction: model.provider == .custom ? { customModel in
                                customModelToEdit = customModel
                            } : nil
                        )

                        // Provenance row — small strip under each card
                        // showing origin (organisation · country · via)
                        // and a colour-coded trust chip. Helps users make
                        // an informed call on whether to use any given
                        // model rather than guessing.
                        ProvenanceStrip(model: model)
                            .padding(.leading, 4)
                            .padding(.trailing, 8)

                        // "Update available" CTA — when the user has a
                        // downloaded model whose metadata says it's been
                        // superseded by a newer version, surface a one-click
                        // upgrade row below the card. Click → download the
                        // newer model and set it as default.
                        if let upgrade = upgradeOption(for: model) {
                            UpdateAvailableBanner(
                                from: model.displayName,
                                to: upgrade.displayName,
                                onUpdate: {
                                    if let newer = upgrade as? WhisperModel {
                                        Task { await whisperModelManager.downloadModel(newer) }
                                    }
                                    Task {
                                        transcriptionModelManager.setDefaultTranscriptionModel(upgrade)
                                    }
                                }
                            )
                            .padding(.horizontal, 4)
                        }
                    }

                    // Import button as a card at the end of the Local list
                    if selectedFilter == .local {
                        HStack(spacing: 8) {
                            Button(action: { presentImportPanel() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import Local Model…")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(CardBackground(isSelected: false))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            InfoTip(
                                "If you've fine-tuned your own Whisper model (with whisper.cpp or via a community release), you can plug it into Neuron Flame here. Click Choose File and pick the .bin file — Neuron Flame loads it as a local model. Useful for accents the stock models struggle with, technical jargon, or to reproduce a specific voice profile. Only ggml-format .bin files are supported (the format whisper.cpp produces). Larger custom models give better accuracy but use more RAM.",
                                learnMoreURL: "https://neuronflame.com/docs/custom-models.html"
                            )
                            .help("Read more about custom local models")
                        }
                    }
                    
                    if selectedFilter == .custom {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                            Text("Only OpenAI-compatible transcription APIs are supported.")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)

                        AddCustomModelCardView(
                            customModelManager: customModelManager,
                            editingModel: customModelToEdit
                        ) {
                            // Refresh the models when a new custom model is added
                            transcriptionModelManager.refreshAllAvailableModels()
                            customModelToEdit = nil // Clear editing state
                        }
                    }
                }
            }
        .padding()
    }



    private var intelMacWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)

            Text("Local models don't work reliably on Intel Macs")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedFilter = .cloud
                }
            }) {
                HStack(spacing: 4) {
                    Text("Use Cloud")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }

    /// Recommendations computed once per body render against the live
    /// merged registry. Kept as a property so both `filteredModels` and
    /// `recommendationReason(for:)` see the same ordering.
    private var liveRecommendations: [RecommendationEngine.Recommendation] {
        RecommendationEngine.recommendations(
            from: transcriptionModelManager.allAvailableModels,
            isAvailableOnCurrentOS: { transcriptionModelManager.isAvailableOnCurrentOS($0) }
        )
    }

    /// Returns the "why" label for a given model on the Recommended tab,
    /// or nil if the model isn't currently in the recommended set.
    private func recommendationReason(for model: any TranscriptionModel) -> String? {
        liveRecommendations.first(where: { $0.model.name == model.name })?.reason
    }

    private var filteredModels: [any TranscriptionModel] {
        switch selectedFilter {
        case .recommended:
            // Driven entirely by RecommendationEngine — no hard-coded model
            // names. As new entries arrive via models.json with better
            // speed/accuracy values, they automatically displace older
            // picks here. See RecommendationEngine.score() for the formula.
            return liveRecommendations.map { $0.model }
        case .local:
            // Hide superseded variants by default. If you've already
            // downloaded an older version (it's on disk), keep it visible
            // — we don't want it to "disappear" out from under you. Also
            // apply any active chip filters (Trust / Organisation / Family)
            // on top.
            let downloadedNames = Set(whisperModelManager.availableModels.map { $0.name })
            let supersededIds = Set(
                transcriptionModelManager.allAvailableModels.compactMap {
                    ModelMetadata.info(for: $0).supersededBy
                }
            )
            return transcriptionModelManager.allAvailableModels.filter { model in
                guard (model.provider == .whisper || model.provider == .nativeApple || model.provider == .fluidAudio)
                    && transcriptionModelManager.isAvailableOnCurrentOS(model) else { return false }
                // Suppress superseded entries unless the user already has them on disk.
                if supersededIds.contains(model.name) && !downloadedNames.contains(model.name) {
                    return false
                }
                // Apply chip filters. Empty selection in a group = no filter.
                let info = ModelMetadata.info(for: model)
                if !trustFilters.isEmpty && !trustFilters.contains(info.trust) { return false }
                if !orgFilters.isEmpty && !orgFilters.contains(ModelMetadata.company(for: model)) { return false }
                if !familyFilters.isEmpty && !familyFilters.contains(ModelMetadata.family(for: model)) { return false }
                return true
            }
        case .cloud:
            return transcriptionModelManager.allAvailableModels.filter { CloudProviderRegistry.provider(for: $0.provider) != nil }
        case .custom:
            return transcriptionModelManager.allAvailableModels.filter { $0.provider == .custom }
        }
    }

    // MARK: - Import Panel
    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bin")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.title = "Select a Whisper ggml .bin model"
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await whisperModelManager.importWhisperModel(from: url)
            }
        }
    }

    // MARK: - Filter chip helpers
    //
    // Each computed property returns the SET of values currently present
    // across the on-device-runnable models, so the filter bar can render
    // chips only for what's actually available. This keeps the bar
    // adaptive — if we never ship a model from Apple, no Apple chip
    // appears in the Organisation row.

    /// All on-device-eligible models (without applying chip filters) — the
    /// universe we pull facet values from. We don't filter by chip
    /// selections here, otherwise unselecting the last chip in a group
    /// would lose that chip from the UI.
    private var localUniverse: [any TranscriptionModel] {
        let downloadedNames = Set(whisperModelManager.availableModels.map { $0.name })
        let supersededIds = Set(
            transcriptionModelManager.allAvailableModels.compactMap {
                ModelMetadata.info(for: $0).supersededBy
            }
        )
        return transcriptionModelManager.allAvailableModels.filter { model in
            guard (model.provider == .whisper || model.provider == .nativeApple || model.provider == .fluidAudio)
                && transcriptionModelManager.isAvailableOnCurrentOS(model) else { return false }
            if supersededIds.contains(model.name) && !downloadedNames.contains(model.name) {
                return false
            }
            return true
        }
    }

    var availableTrustsInLocalSet: [ModelMetadata.Trust] {
        let trusts = Set(localUniverse.map { ModelMetadata.info(for: $0).trust })
        // Order: Verified first, then Community, then Custom — most-trusted first.
        return [.verified, .community, .custom].filter { trusts.contains($0) }
    }

    var availableOrgsInLocalSet: [String] {
        Set(localUniverse.map { ModelMetadata.company(for: $0) })
            .sorted()
    }

    var availableFamiliesInLocalSet: [String] {
        Set(localUniverse.map { ModelMetadata.family(for: $0) })
            .sorted()
    }

    /// If the given model has a `supersededBy` pointer AND the user has
    /// the model downloaded AND the newer model exists in the registry,
    /// return that newer model — caller renders the "Update available"
    /// CTA. Otherwise nil.
    private func upgradeOption(for model: any TranscriptionModel) -> (any TranscriptionModel)? {
        guard let supersededByName = ModelMetadata.info(for: model).supersededBy else { return nil }
        let downloaded = whisperModelManager.availableModels.contains { $0.name == model.name }
        guard downloaded else { return nil }
        return transcriptionModelManager.allAvailableModels.first { $0.name == supersededByName }
    }
}

// MARK: - Local filter bar
//
// Three groups of multi-select chips (Trust / Organisation / Family) shown
// at the top of the Local tab. Empty selection within a group = "include
// all from this group". Collapses to a single summary row when not in use.
private struct LocalFilterBar: View {
    let availableTrusts: [ModelMetadata.Trust]
    let availableOrgs: [String]
    let availableFamilies: [String]
    @Binding var selectedTrusts: Set<ModelMetadata.Trust>
    @Binding var selectedOrgs: Set<String>
    @Binding var selectedFamilies: Set<String>
    @Binding var isExpanded: Bool

    private var activeFilterCount: Int {
        selectedTrusts.count + selectedOrgs.count + selectedFamilies.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header — click to expand/collapse the filter groups.
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle\(activeFilterCount > 0 ? ".fill" : "")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(activeFilterCount > 0 ? ZivaTheme.primary : ZivaTheme.onSurfaceVariant)

                    Text(activeFilterCount == 0 ? "Filter" : "\(activeFilterCount) filter\(activeFilterCount == 1 ? "" : "s") active")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(activeFilterCount > 0 ? ZivaTheme.primary : ZivaTheme.onSurface)

                    if activeFilterCount > 0 {
                        Button {
                            selectedTrusts.removeAll()
                            selectedOrgs.removeAll()
                            selectedFamilies.removeAll()
                        } label: {
                            Text("Clear")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ZivaTheme.surfaceContainerHigh))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ZivaTheme.onSurfaceVariant)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                if !availableTrusts.isEmpty {
                    filterGroup(
                        label: "Trust",
                        chips: availableTrusts.map { ($0.label, selectedTrusts.contains($0)) },
                        onToggle: { idx in
                            let trust = availableTrusts[idx]
                            if selectedTrusts.contains(trust) { selectedTrusts.remove(trust) }
                            else { selectedTrusts.insert(trust) }
                        }
                    )
                }
                if !availableOrgs.isEmpty {
                    filterGroup(
                        label: "Organisation",
                        chips: availableOrgs.map { ($0, selectedOrgs.contains($0)) },
                        onToggle: { idx in
                            let org = availableOrgs[idx]
                            if selectedOrgs.contains(org) { selectedOrgs.remove(org) }
                            else { selectedOrgs.insert(org) }
                        }
                    )
                }
                if !availableFamilies.isEmpty {
                    filterGroup(
                        label: "Family",
                        chips: availableFamilies.map { ($0, selectedFamilies.contains($0)) },
                        onToggle: { idx in
                            let fam = availableFamilies[idx]
                            if selectedFamilies.contains(fam) { selectedFamilies.remove(fam) }
                            else { selectedFamilies.insert(fam) }
                        }
                    )
                }
            }
        }
        .padding(12)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func filterGroup(label: String, chips: [(String, Bool)], onToggle: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(ZivaTheme.onSurfaceVariant)

            HStack(spacing: 6) {
                ForEach(Array(chips.enumerated()), id: \.offset) { idx, chip in
                    Button { onToggle(idx) } label: {
                        Text(chip.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(chip.1 ? .white : ZivaTheme.onSurface)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(chip.1 ? ZivaTheme.primary : ZivaTheme.surfaceContainerLow)
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    chip.1 ? ZivaTheme.primary : ZivaTheme.outlineVariant,
                                    lineWidth: 0.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Update available banner
//
// Slim row that sits below a model card when the user has an older version
// downloaded and a newer one exists in the registry (driven by
// ModelMetadata.supersededBy). One click downloads the newer model and
// sets it as the default. The user can still find their old version in
// the Local list — we don't delete it for them.
private struct UpdateAvailableBanner: View {
    let from: String
    let to: String
    let onUpdate: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ZivaTheme.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text("Newer version available")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ZivaTheme.primary)
                Text("\(to) replaces \(from). Local-first; download and switch in one click.")
                    .font(.system(size: 10))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Button(action: onUpdate) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 10))
                    Text("Update").font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [ZivaTheme.primary, Color(red: 0.75, green: 0.15, blue: 0.83)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            LinearGradient(
                colors: [ZivaTheme.primaryFixed.opacity(0.5), ZivaTheme.surfaceContainerLowest],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(ZivaTheme.primary.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Provenance strip
//
// Small horizontal row under each model card showing:
//   • Origin string from ModelMetadata (organisation · country · via)
//   • A coloured trust chip (Verified / Community / Custom)
//   • An "introduced YYYY-MM" hint when the date is known
//
// All info comes from ModelMetadata.info(_:), which merges the hard-coded
// `predefined` map with whatever flowed in via the remote catalogue. So
// every model — including future ones we add to models.json — gets the
// provenance treatment automatically.
private struct ProvenanceStrip: View {
    let model: any TranscriptionModel

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"   // e.g. "Apr 2026"
        return f
    }()

    var body: some View {
        let info = ModelMetadata.info(for: model)
        HStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.7))
            Text(info.origin)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineLimit(1)
                .truncationMode(.tail)
            if let date = info.introduced {
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.5))
                Text("Introduced \(Self.dateFormatter.string(from: date))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.85))
            }
            Spacer(minLength: 0)
            TrustChip(trust: info.trust)
        }
        .padding(.horizontal, 6)
        .padding(.top, 2)
    }
}

/// Tiered trust chip — colour communicates the level. Verified is brand
/// green (sturdy / audited), Community is brand violet (open source /
/// community-vetted), Custom is amber (caution: you brought this).
private struct TrustChip: View {
    let trust: ModelMetadata.Trust

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(dotColor)
                .frame(width: 6, height: 6)
            Text(trust.label.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(backgroundColor)
        )
    }

    private var dotColor: Color {
        switch trust {
        case .verified:  return Color(red: 0.06, green: 0.72, blue: 0.50)
        case .community: return Color(red: 0.49, green: 0.23, blue: 0.93)
        case .custom:    return Color(red: 0.98, green: 0.65, blue: 0.10)
        }
    }
    private var textColor: Color {
        switch trust {
        case .verified:  return Color(red: 0.06, green: 0.48, blue: 0.34)
        case .community: return Color(red: 0.32, green: 0.15, blue: 0.62)
        case .custom:    return Color(red: 0.65, green: 0.42, blue: 0.05)
        }
    }
    private var backgroundColor: Color {
        switch trust {
        case .verified:  return Color(red: 0.06, green: 0.72, blue: 0.50).opacity(0.10)
        case .community: return Color(red: 0.49, green: 0.23, blue: 0.93).opacity(0.10)
        case .custom:    return Color(red: 0.98, green: 0.65, blue: 0.10).opacity(0.12)
        }
    }
}

// MARK: - Reason badge
//
// The coloured capsule we render above each row on the Recommended tab.
// Each recommendation category gets its own gradient so the visual cue
// matches the semantic — speed feels energetic (orange/amber), accuracy
// feels solid and trustworthy (emerald/teal), multilingual feels global
// (blue/indigo), cloud feels neutral (slate). "Best overall" keeps the
// brand violet/magenta so it remains the visual anchor.
private struct ReasonBadge: View {
    let reason: String

    var body: some View {
        HStack(spacing: 0) {
            Text(reason.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(gradient)
                )
            Spacer(minLength: 0)
        }
    }

    private var gradient: LinearGradient {
        let colors: [Color]
        switch reason {
        case "Best overall":
            colors = [Color(red: 0.49, green: 0.23, blue: 0.93),   // violet
                      Color(red: 0.75, green: 0.15, blue: 0.83)]   // magenta
        case "Fastest":
            colors = [Color(red: 0.98, green: 0.45, blue: 0.09),   // orange
                      Color(red: 0.98, green: 0.75, blue: 0.14)]   // amber
        case "Most accurate":
            colors = [Color(red: 0.06, green: 0.72, blue: 0.50),   // emerald
                      Color(red: 0.08, green: 0.72, blue: 0.66)]   // teal
        case "Best for multilingual":
            colors = [Color(red: 0.23, green: 0.51, blue: 0.96),   // sky blue
                      Color(red: 0.39, green: 0.40, blue: 0.95)]   // indigo
        case "Best cloud":
            colors = [Color(red: 0.39, green: 0.45, blue: 0.55),   // slate
                      Color(red: 0.58, green: 0.64, blue: 0.72)]   // slate-300
        default:
            colors = [Color(red: 0.49, green: 0.23, blue: 0.93),
                      Color(red: 0.75, green: 0.15, blue: 0.83)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }
}
