import Foundation

/// Curated metadata that powers the "country of origin", "trust level", and
/// "introduced on" surfaces in the AI Models tab — and feeds the
/// RecommendationEngine's recency tiebreak + superseded-by filtering.
///
/// **Two sources merge into one lookup:**
///   1. The hard-coded `predefined` map below — entries for every model in
///      `TranscriptionModelRegistry.predefinedModels`. We maintain these
///      manually because the hard-coded model structs don't have a place
///      to carry this metadata.
///   2. The remote `models.json` catalogue (via `RemoteModelEntry`) —
///      every entry carries its own origin/trust/introduced/superseded_by
///      fields. The remote catalogue automatically registers itself with
///      this lookup as soon as it loads.
///
/// **Why a separate lookup instead of fields on the model protocol?**
/// Touching the TranscriptionModel protocol means touching every concrete
/// type (NativeAppleModel, FluidAudioModel, CloudModel, CustomCloudModel,
/// WhisperModel, ImportedWhisperModel) — and metadata like "country of
/// origin" doesn't really belong on a transcription-model abstraction.
/// This keeps the concerns separated.
enum ModelMetadata {

    /// Provenance + audit posture for one model.
    struct Info {
        /// Human-readable origin: "OpenAI · United States",
        /// "NVIDIA · United States · via FluidAudio",
        /// "HuggingFace · International".
        let origin: String

        /// How much we trust this model's provenance.
        let trust: Trust

        /// When the model was first published. Used as a tiebreak in
        /// recommendations (newer wins on equal score) and to drive the
        /// "Newest" label in the UI.
        let introduced: Date?

        /// If a newer model in the same family replaces this one, this is
        /// the id of that replacement. The Local tab hides superseded
        /// entries by default; the RecommendationEngine excludes them.
        let supersededBy: String?
    }

    /// Tiered trust label, shown as a coloured chip on each model card.
    enum Trust: String {
        /// Known organisation, publicly documented weights, widely audited.
        /// Apple, OpenAI, NVIDIA, major cloud providers.
        case verified
        /// Open-source community port or distillation. Weights public but
        /// no central trust authority. HuggingFace distillations, etc.
        case community
        /// User-supplied endpoint with no first-party metadata. We can't
        /// vouch for anything — buyer beware.
        case custom

        var label: String {
            switch self {
            case .verified:  return "Verified"
            case .community: return "Community"
            case .custom:    return "Custom"
            }
        }
    }

    // MARK: - Public lookup

    /// Returns metadata for the given model. Looks up by model `name` in
    /// (a) the remote catalogue cache, then (b) the hard-coded predefined
    /// map, falling back to a neutral "Unknown" Info if nothing matches.
    static func info(for model: any TranscriptionModel) -> Info {
        // First check the remote catalogue — its entries carry metadata
        // directly. This means new models added via models.json get their
        // origin/trust badges automatically with no code change.
        if let remote = remoteEntries[model.name] {
            return remote
        }
        // Fall back to the hard-coded map for built-in models.
        if let pre = predefined[model.name] {
            return pre
        }
        // Heuristic fallback by provider — handles models we haven't
        // explicitly mapped (e.g. a Whisper variant we never enumerated).
        return Info(
            origin: heuristicOrigin(for: model),
            trust: heuristicTrust(for: model),
            introduced: nil,
            supersededBy: nil
        )
    }

    /// Called by `RemoteModelCatalogue.refresh()` after a successful fetch.
    /// We merge the remote entries into our lookup so `info(for:)` resolves
    /// them on subsequent queries.
    static func registerRemoteEntries(_ entries: [String: Info]) {
        remoteEntries = entries
    }

    /// Extract the company / organisation name from an Info (the first
    /// segment of the origin string before " · "). Used by the Local-tab
    /// filter chips so the user can narrow by who made the model.
    static func company(for model: any TranscriptionModel) -> String {
        let origin = info(for: model).origin
        return origin.split(separator: " · ").first.map(String.init) ?? origin
    }

    /// Extract the country of origin from an Info — the second segment of
    /// the origin string ("OpenAI · United States · via whisper.cpp" →
    /// "United States"). Used by the Country filter chips on the Local
    /// tab so users can choose to use only models from specific
    /// jurisdictions if that matters to them.
    static func country(for model: any TranscriptionModel) -> String {
        let parts = info(for: model).origin.split(separator: " · ").map(String.init)
        if parts.count >= 2 { return parts[1] }
        return parts.first ?? info(for: model).origin
    }

    /// A simple "family" bucket for filtering — broader than the strict
    /// model `family` field in JSON. Maps:
    ///   • Whisper variants → "Whisper"
    ///   • Parakeet variants → "Parakeet"
    ///   • Apple Speech     → "Apple Speech"
    ///   • Cloud providers  → "Cloud"
    ///   • Custom endpoint  → "Custom"
    static func family(for model: any TranscriptionModel) -> String {
        switch model.provider {
        case .whisper:    return "Whisper"
        case .fluidAudio: return "Parakeet"
        case .nativeApple: return "Apple Speech"
        case .custom:     return "Custom"
        default:          return "Cloud"
        }
    }

    // MARK: - Private storage

    private static var remoteEntries: [String: Info] = [:]

    /// Curated metadata for every model in
    /// `TranscriptionModelRegistry.predefinedModels`. Keyed by model `name`.
    /// Keep entries in sync when adding models to the predefined list.
    private static let predefined: [String: Info] = [
        // Apple's on-device speech model (macOS 26+).
        "apple-speech": Info(
            origin: "Apple · United States",
            trust: .verified,
            introduced: date("2025-09-15"),
            supersededBy: nil
        ),

        // NVIDIA's Parakeet via FluidAudio's ANE port.
        "parakeet-tdt-0.6b-v2": Info(
            origin: "NVIDIA · United States · via FluidAudio",
            trust: .verified,
            introduced: date("2024-04-01"),
            supersededBy: "parakeet-tdt-0.6b-v3"
        ),
        "parakeet-tdt-0.6b-v3": Info(
            origin: "NVIDIA · United States · via FluidAudio",
            trust: .verified,
            introduced: date("2026-01-22"),
            supersededBy: nil
        ),

        // OpenAI's Whisper family, ggerganov port.
        "ggml-tiny": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2022-09-21"),
            supersededBy: nil
        ),
        "ggml-tiny.en": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2022-09-21"),
            supersededBy: nil
        ),
        "ggml-base": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2022-09-21"),
            supersededBy: nil
        ),
        "ggml-base.en": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2022-09-21"),
            supersededBy: nil
        ),
        "ggml-large-v2": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2022-12-09"),
            supersededBy: "ggml-large-v3"
        ),
        "ggml-large-v3": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2023-11-06"),
            supersededBy: "ggml-large-v3-turbo"
        ),
        "ggml-large-v3-turbo": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2024-10-01"),
            supersededBy: nil
        ),
        "ggml-large-v3-turbo-q5_0": Info(
            origin: "OpenAI · United States · via whisper.cpp",
            trust: .verified,
            introduced: date("2024-10-15"),
            supersededBy: nil
        ),
    ]

    // MARK: - Helpers

    private static func date(_ iso: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: iso)
    }

    private static func heuristicOrigin(for model: any TranscriptionModel) -> String {
        switch model.provider {
        case .whisper:    return "OpenAI · United States"
        case .nativeApple: return "Apple · United States"
        case .fluidAudio: return "NVIDIA · United States · via FluidAudio"
        case .custom:     return "User-provided endpoint"
        default:          return "—"
        }
    }

    private static func heuristicTrust(for model: any TranscriptionModel) -> Trust {
        switch model.provider {
        case .whisper, .nativeApple, .fluidAudio: return .verified
        case .custom: return .custom
        default: return .community
        }
    }
}
