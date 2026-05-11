import Foundation

/// Picks transcription models to surface on the "Recommended" tab —
/// dynamically, from whatever's currently in the merged registry. This
/// replaces the previous hard-coded list of 4 model names, so when a new
/// faster / more accurate model lands via the remote catalogue, it
/// automatically competes for a slot.
///
/// **Each recommendation carries a `reason` label** ("Best overall",
/// "Fastest local", etc.) — the UI surfaces this above the model card so
/// users understand WHY the app is suggesting that particular model rather
/// than just guessing at intent.
///
/// **The scoring formula** is `accuracy² × speed + EnglishBias`. Squaring
/// accuracy means a 0.05 accuracy improvement (e.g. 0.94 → 0.99 WER) beats
/// a 0.10 speed improvement at the same accuracy — users notice mistakes
/// more than latency. The English bias is small (0.05) and reflects that
/// the majority of dictation use is English; multilingual models still
/// get listed in the "Best for multilingual" slot.
enum RecommendationEngine {

    struct Recommendation {
        let model: any TranscriptionModel
        let reason: String
    }

    /// Compute up to ~5 recommended models from the merged registry.
    /// Each returned recommendation is distinct (we de-dupe across
    /// categories so the same model doesn't appear under two reasons).
    static func recommendations(
        from models: [any TranscriptionModel],
        isAvailableOnCurrentOS: (any TranscriptionModel) -> Bool
    ) -> [Recommendation] {
        // Two filters compose the candidate pool:
        //   1. Available on current OS — NativeAppleModel needs macOS 26+.
        //   2. Not superseded — Parakeet V2 is hidden because V3 supersedes
        //      it; old Whisper Large v3 hidden in favour of Turbo. Power
        //      users can still find every variant in the Local tab.
        //
        // A model is superseded if its OWN metadata has a non-nil
        // supersededBy pointer (i.e., the model says "I've been replaced
        // by X"). Previously this used a flipped check that accidentally
        // hid the newer model instead — that's why Recommended kept
        // showing Parakeet V2 as 'Fastest' even though V3 should have
        // won the slot. Fixed in v1.90.
        let pool = models.filter { model in
            isAvailableOnCurrentOS(model)
                && ModelMetadata.info(for: model).supersededBy == nil
        }
        guard !pool.isEmpty else { return [] }

        var picks: [Recommendation] = []
        var taken: Set<String> = []

        func add(_ model: (any TranscriptionModel)?, reason: String) {
            guard let model, !taken.contains(model.name) else { return }
            picks.append(Recommendation(model: model, reason: reason))
            taken.insert(model.name)
        }

        // Subsets we'll pull category winners from.
        let local = pool.filter { isLocal($0) }
        let cloud = pool.filter { isCloud($0) }
        let multilingual = pool.filter { $0.isMultilingualModel }

        // 1. Best overall — highest combined score. This is the default
        //    pick for most users; usually a mid-size English model.
        add(pool.max(by: scoreThenRecency), reason: "Best overall")

        // 2. Fastest local — highest `speed` among models that run on the
        //    user's Mac (i.e. no cloud round-trip). Picks the responsiveness
        //    winner regardless of accuracy.
        add(local.max(by: speedThenRecency), reason: "Fastest")

        // 3. Most accurate local — highest `accuracy` regardless of speed
        //    or size. The "I care about quality, I'll wait" pick.
        add(local.max(by: accuracyThenRecency), reason: "Most accurate")

        // 4. Best multilingual — best score in the multilingual subset.
        //    Only adds a fourth row if a strong multilingual option exists
        //    and isn't already in the picks via a prior category.
        if !taken.contains(where: { name in multilingual.contains(where: { $0.name == name }) }) {
            add(multilingual.max(by: scoreThenRecency), reason: "Best for multilingual")
        }

        // 5. Best cloud — best score among cloud-hosted models. Useful
        //    when the user wants Whisper Large quality without the local
        //    compute cost (e.g. Groq's hosted Whisper).
        add(cloud.max(by: scoreThenRecency), reason: "Best cloud")

        return picks
    }

    // MARK: - Comparators
    //
    // Each comparator returns "is $0 strictly less preferable than $1"
    // — they're suitable as the `by:` argument to `Array.max(by:)`. Each
    // breaks ties by recency (newer wins), then by name as a final
    // deterministic fallback so the order is stable across renders.

    private static func scoreThenRecency(_ a: any TranscriptionModel, _ b: any TranscriptionModel) -> Bool {
        let sa = score(a), sb = score(b)
        if sa != sb { return sa < sb }
        return olderThan(a, b)
    }

    private static func speedThenRecency(_ a: any TranscriptionModel, _ b: any TranscriptionModel) -> Bool {
        let va = metrics(a).speed, vb = metrics(b).speed
        if va != vb { return va < vb }
        return olderThan(a, b)
    }

    private static func accuracyThenRecency(_ a: any TranscriptionModel, _ b: any TranscriptionModel) -> Bool {
        let va = metrics(a).accuracy, vb = metrics(b).accuracy
        if va != vb { return va < vb }
        return olderThan(a, b)
    }

    /// Returns true if `a` is older than `b` (so it "loses" in a max
    /// comparator). Missing dates lose to known dates; equal dates fall
    /// back to lexicographic name ordering for stability.
    private static func olderThan(_ a: any TranscriptionModel, _ b: any TranscriptionModel) -> Bool {
        let da = ModelMetadata.info(for: a).introduced
        let db = ModelMetadata.info(for: b).introduced
        switch (da, db) {
        case (nil, nil):
            return a.name > b.name
        case (nil, _):
            return true              // unknown date is "older" than any known
        case (_, nil):
            return false
        case (let lhs?, let rhs?):
            if lhs != rhs { return lhs < rhs }
            return a.name > b.name
        }
    }

    // MARK: - Scoring

    /// Accuracy-squared × speed, plus a small English-only nudge. Tunable
    /// here in one place — adjust the weights if the recommendations ever
    /// drift away from what feels right.
    private static func score(_ model: any TranscriptionModel) -> Double {
        let m = metrics(model)
        let base = pow(m.accuracy, 2) * m.speed
        let englishBias = model.isMultilingualModel ? 0.0 : 0.04
        return base + englishBias
    }

    /// Extracts speed + accuracy from the concrete model type. The
    /// TranscriptionModel protocol doesn't expose these (some types like
    /// CustomCloudModel and NativeAppleModel don't carry them), so we
    /// pattern-match and fall back to neutral 0.5/0.5 for unknown shapes —
    /// which keeps unknown models in the pool but unable to dominate the
    /// recommendation slots.
    private static func metrics(_ model: any TranscriptionModel) -> (speed: Double, accuracy: Double) {
        switch model {
        case let m as WhisperModel:      return (m.speed, m.accuracy)
        case let m as FluidAudioModel:   return (m.speed, m.accuracy)
        case let m as CloudModel:        return (m.speed, m.accuracy)
        case is NativeAppleModel:        return (0.9, 0.88)   // SpeechAnalyzer estimates
        case is CustomCloudModel:        return (0.6, 0.85)   // unknown — assume "decent cloud"
        default:                          return (0.5, 0.5)
        }
    }

    private static func isLocal(_ model: any TranscriptionModel) -> Bool {
        switch model.provider {
        case .whisper, .nativeApple, .fluidAudio: return true
        default: return false
        }
    }

    private static func isCloud(_ model: any TranscriptionModel) -> Bool {
        CloudProviderRegistry.provider(for: model.provider) != nil
            || model.provider == .custom
    }
}
