import Foundation
import os

/// Fetches Neuron Flame's remote model catalogue from
/// `https://neuronflame.com/models.json` and merges it with the hard-coded
/// `TranscriptionModelRegistry.predefinedModels` list.
///
/// The point of this service is that **new transcription models can be added
/// or deprecated without shipping a new app version**. When a new Whisper
/// variant, Parakeet release, or distilled model becomes worth exposing, we
/// edit the JSON on neuronflame.com and every running install picks it up on
/// its next refresh (24h cycle, or on launch).
///
/// **Failure mode**: if the fetch fails (offline, server down, JSON
/// malformed), we fall back to whatever's cached in UserDefaults from the
/// last successful refresh, and beyond that to the hard-coded list. Worst
/// case is "user sees the in-binary defaults", never a broken state.
///
/// **Schema versioning**: each models.json carries a `version` integer. If
/// that ever exceeds `Self.supportedSchemaVersion`, we ignore the remote
/// catalogue entirely (the client doesn't understand the new shape).
// Not @MainActor — `remoteModels` is read by the non-isolated
// `TranscriptionModelRegistry.models` static property, so the class itself
// can't be MainActor-bound. The @Published mutations inside `refresh()`
// instead hop to the main actor explicitly via `MainActor.run`.
final class RemoteModelCatalogue: ObservableObject {
    static let shared = RemoteModelCatalogue()

    /// The merged list of remote-discovered models, ready to be folded into
    /// the registry. Empty if no successful fetch yet (or if a fetch returned
    /// zero entries).
    @Published private(set) var remoteModels: [any TranscriptionModel] = []

    /// Last time we successfully refreshed from the network. nil = never.
    @Published private(set) var lastRefreshed: Date?

    /// True while a fetch is in flight (drives the spinning indicator on the
    /// Refresh button in the AI Models tab).
    @Published private(set) var isRefreshing = false

    private static let catalogueURL = URL(string: "https://neuronflame.com/models.json")!
    private static let supportedSchemaVersion = 1
    private static let cacheKey = "RemoteModelCatalogue.cachedEntries"
    private static let lastRefreshedKey = "RemoteModelCatalogue.lastRefreshed"

    private let logger = Logger(subsystem: "com.neuronflame.app", category: "RemoteModelCatalogue")
    private let urlSession: URLSession

    private init() {
        // Dedicated URLSession with caching disabled so we always see the
        // latest catalogue. The server already sends no-cache headers but
        // belt-and-braces — Sparkle's stale-cache bug taught us not to trust
        // the protocol cache for things that should always be fresh.
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        self.urlSession = URLSession(configuration: config)

        // Restore the last good catalogue from disk on init so the AI Models
        // tab has something useful even before the first refresh completes.
        loadFromCache()
    }

    // MARK: - Public API

    /// Refresh the catalogue from neuronflame.com. Safe to call repeatedly;
    /// concurrent refreshes are coalesced via the `isRefreshing` gate.
    func refresh() async {
        // Coalesce concurrent refreshes. The read is racy but the cost of a
        // duplicate fetch is just a wasted HTTP round-trip.
        guard !isRefreshing else { return }
        await MainActor.run { self.isRefreshing = true }
        defer { Task { @MainActor in self.isRefreshing = false } }

        do {
            var request = URLRequest(url: Self.catalogueURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 12

            let (data, response) = try await urlSession.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                logger.warning("Catalogue refresh: non-HTTP response")
                return
            }
            guard (200...299).contains(http.statusCode) else {
                logger.warning("Catalogue refresh: HTTP \(http.statusCode, privacy: .public)")
                return
            }

            let envelope = try JSONDecoder().decode(CatalogueEnvelope.self, from: data)

            guard envelope.version <= Self.supportedSchemaVersion else {
                logger.notice("Catalogue refresh: schema version \(envelope.version, privacy: .public) exceeds supported \(Self.supportedSchemaVersion, privacy: .public). Ignoring.")
                return
            }

            // Filter out entries whose min_app_version exceeds ours, AND
            // entries that have been deprecated. Deprecated entries stay in
            // the JSON for one or two releases so users with older catalogue
            // caches don't see ghost models, then they're removed from the
            // JSON entirely.
            let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
            let filtered = envelope.models.filter { entry in
                guard entry.deprecatedAt == nil else { return false }
                if let minVersion = entry.minAppVersion {
                    return Self.compareVersions(currentVersion, minVersion) != .orderedAscending
                }
                return true
            }

            let materialised = filtered.compactMap { $0.toTranscriptionModel() }
            let now = Date()

            await MainActor.run {
                self.remoteModels = materialised
                self.lastRefreshed = now
            }
            persistToCache(entries: filtered, stamp: now)

            logger.notice("Catalogue refresh OK: \(materialised.count, privacy: .public) models, version \(envelope.version, privacy: .public)")
        } catch {
            logger.error("Catalogue refresh failed: \(error.localizedDescription, privacy: .public). Keeping cached catalogue.")
        }
    }

    // MARK: - Persistence

    private func loadFromCache() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: Self.cacheKey),
           let entries = try? JSONDecoder().decode([RemoteModelEntry].self, from: data) {
            self.remoteModels = entries.compactMap { $0.toTranscriptionModel() }
            logger.notice("Restored \(self.remoteModels.count, privacy: .public) cached remote models")
        }
        if let stamp = defaults.object(forKey: Self.lastRefreshedKey) as? Date {
            self.lastRefreshed = stamp
        }
    }

    private func persistToCache(entries: [RemoteModelEntry], stamp: Date) {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: Self.cacheKey)
        }
        defaults.set(stamp, forKey: Self.lastRefreshedKey)
    }

    // MARK: - Helpers

    /// Lexicographic version comparison good enough for "1.85" vs "1.74"
    /// style versions. Splits on dots, compares numerically.
    private static func compareVersions(_ a: String, _ b: String) -> ComparisonResult {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for i in 0..<count {
            let lhs = i < aParts.count ? aParts[i] : 0
            let rhs = i < bParts.count ? bParts[i] : 0
            if lhs < rhs { return .orderedAscending }
            if lhs > rhs { return .orderedDescending }
        }
        return .orderedSame
    }
}

// MARK: - JSON shape

/// Wire format. Matches website/models.json exactly. Keep field names in sync.
private struct CatalogueEnvelope: Codable {
    let version: Int
    let updatedAt: String?
    let models: [RemoteModelEntry]

    enum CodingKeys: String, CodingKey {
        case version
        case updatedAt = "updated_at"
        case models
    }
}

/// One model in the remote catalogue. We keep this separate from the
/// concrete `WhisperModel`/`FluidAudioModel` types so the wire format is
/// stable even if the internal model structs change shape.
struct RemoteModelEntry: Codable {
    let id: String
    let family: String         // "whisper" | "fluid_audio" | "native_apple"
    let displayName: String
    let description: String
    let size: String
    let speed: Double
    let accuracy: Double
    let ramUsage: Double
    let languages: String      // "english" | "multi"
    let introduced: String?
    let deprecatedAt: String?
    let minAppVersion: String?
    let isNew: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case family
        case displayName  = "display_name"
        case description
        case size
        case speed
        case accuracy
        case ramUsage     = "ram_usage"
        case languages
        case introduced
        case deprecatedAt = "deprecated_at"
        case minAppVersion = "min_app_version"
        case isNew        = "is_new"
    }

    /// Convert the wire shape into one of the concrete TranscriptionModel
    /// types the rest of the app understands. Returns nil if the entry's
    /// `family` isn't recognised (forward-compatibility — future schema
    /// versions might introduce new families this client can't handle).
    func toTranscriptionModel() -> (any TranscriptionModel)? {
        let isMultilingual = languages == "multi"
        switch family {
        case "whisper":
            return WhisperModel(
                name: id,
                displayName: displayName,
                size: size,
                supportedLanguages: LanguageDictionary.forProvider(
                    isMultilingual: isMultilingual,
                    provider: .whisper
                ),
                description: description,
                speed: speed,
                accuracy: accuracy,
                ramUsage: ramUsage
            )
        case "fluid_audio":
            return FluidAudioModel(
                name: id,
                displayName: displayName,
                description: description,
                size: size,
                speed: speed,
                accuracy: accuracy,
                ramUsage: ramUsage,
                supportsStreaming: true,
                supportedLanguages: LanguageDictionary.forProvider(
                    isMultilingual: isMultilingual,
                    provider: .fluidAudio
                )
            )
        default:
            return nil
        }
    }
}
