<!-- Generated 2026-07-10 by an 82-agent capability study: 342 ideas, 57 clusters, 5-judge scoring, adversarial validation. -->

# Neuron Flame — Capability Roadmap (v1.93 → v2.x)

## 1. Executive summary

Neuron Flame's moat is not feature count — GPL means anything shippable is copyable back into VoiceInk — it is trust, polish, and reliability under real-world conditions. This roadmap therefore puts crash-safe recording, paste resilience, and Bluetooth audio quality ahead of every new capability, then sequences the ambitious voice features behind two shared foundations: instant-feel latency and a single voice-command parser. Meeting recording, diarization, and wake-word listening are explicitly rejected as category pivots that contradict the no-always-on-mic, privacy-first positioning.

## 2. Ship this week (quick wins)

**Crash-safe recording recovery.** Write the in-flight WAV to disk continuously (already recording via `VoiceInk/CoreAudioRecorder.swift`); on next launch, if an orphaned recording exists with no matching transcript, offer one-click "recover and transcribe" through `Transcription/Engine/TranscriptionPipeline.swift` and `AudioFileProcessor.swift`. A lost 3-minute dictation is the single worst trust event the app can produce.

**Paste-failure detection and fallback.** In `VoiceInk/CursorPaster.swift`, detect secure-input mode (`IsSecureEventInputEnabled()`) and Accessibility-insert failures; fall back through the chain (AX insert → Cmd-V paste → direct-type from v1.92 → clipboard + notification "text is on your clipboard"). Never silently drop text. Log the failing app's bundle ID to `Services/LogExporter.swift` diagnostics.

**Bluetooth/AirPods sample-rate guard.** In `VoiceInk/Services/AudioDeviceManager.swift` and `AudioDeviceConfiguration.swift`, detect when the input has dropped to 8/16 kHz HFP and either warn ("AirPods in call mode — quality reduced") or auto-prefer the built-in mic (user toggle in `Views/Settings/AudioInputSettingsView.swift`). This is the most common "transcription suddenly got bad" complaint on macOS.

**Permission-reset resilience.** Extend `Views/PermissionsView.swift` and `Views/Common/SystemStatusBanner.swift` to re-check Accessibility/mic/screen-capture on every launch and after macOS updates (TCC resets are routine), with a one-click repair flow instead of mysterious paste failures.

**Homebrew cask.** Submit `neuron-flame` to homebrew-cask pointing at the notarised DMG. Zero code, meaningful distribution, and it sidesteps the right-click-to-open friction documented in README.md.

## 3. Next release (v2.0 candidates)

**Instant-feel latency pass.** Profile hotkey-release → paste in `Transcription/Engine/VoiceInkEngine.swift`: keep the selected model warm (`Services/ModelPrewarmService.swift` exists — make it aggressive), begin decoding while recording via the existing streaming path, and pre-fetch the enhancement connection. Target sub-second for short utterances. This is a prerequisite for ghost-text streaming and self-correction UX, so it goes first, not mid-list.

**Voice-command parser (the grammar).** One post-transcription parsing layer in `Transcription/Processing/` that recognises command spans in the transcript stream. Built once, it makes three features thin: spoken punctuation ("comma", "new paragraph"), spoken self-correction ("scratch that", "no wait, make that Tuesday"), and snippets/macros ("insert my address"). Built separately they'd yield incompatible grammars; the parser ships first with punctuation only (lowest risk), corrections and snippets follow as grammar entries. Snippet storage rides the existing dictionary SwiftData store (`Models/WordReplacement.swift` pattern).

**Sparkle/distribution hardening.** The Hostinger-FTP appcast is a single point of failure and the EdDSA private key is a single point of catastrophe. Move appcast + DMG to redundant hosting (or GitHub Releases as mirror), document key custody, keep an offline key backup. Half a day; protects every user.

**Settings & dictionary sync across Macs.** The *real* iCloud need — not transcript sync. Sync dictionary, replacements, prompts, and Power Mode configs via iCloud Drive file or NSUbiquitousKeyValueStore, building on `Services/ImportExportService.swift`. Avoids the CloudKit container/notarisation trap entirely until the container is registered.

## 4. Strategic bets (sequenced)

1. **Upstream-fork decision (decide before any of the below).** VoiceInk keeps shipping; a pipeline rewrite or deep parser integration makes future merges impossible. Recommendation: declare hard divergence now, do one final selective upstream sync, and stop tracking. Every subsequent bet assumes this.
2. **Ghost-text streaming UX.** Words appear at the cursor as you speak, corrected as the word-agreement engine (`Transcription/Streaming/WordAgreementEngine.swift`) firms up. Depends on the latency pass and the direct-type insertion machinery. This is the visible differentiator against Wispr Flow.
3. **Full self-correction UX.** Parser grammar + ghost text combined: spoken edits visibly rewrite the ghost span. Only after both prerequisites are stable.
4. **Voice assistant mode (constrained).** "Ask" prompts routed to the existing `Services/AIEnhancement/AIEnhancementService.swift` with the answer typed at cursor — a parser grammar entry, not a new subsystem. Explicitly *not* an agent platform.
5. **UI localization.** Post-2.0, once strings stabilise; do not localise a moving target.

## 5. Deliberately not doing

- **Meeting Mode + speaker diarization.** A category pivot into Granola/MacWhisper territory: system-audio capture permissions, long-recording storage, and two-party consent law exposure, all straining the privacy story. Neuron Flame is a dictation tool, not a recorder.
- **Wake word / always-on listening.** Directly contradicts the "mic is live only while you hold the key" trust promise. The hotkey *is* the privacy feature.
- **Mac App Store.** Permanently off: unsandboxed, Accessibility, Apple Events, screen capture. Homebrew + notarised DMG is the distribution story.
- **Monetisation buildout.** The Polar license/trial code stays dormant; donation-supported per README. Consider deleting the dead code (`Services/PolarService.swift`, `Views/License*.swift`) in a cleanup pass instead.
- **CloudKit transcript sync.** The container isn't registered; enabling it crashes launch and breaks notarisation. Settings sync (Section 3) covers the actual need.
- **Feature-count parity with VoiceInk upstream.** GPL makes features copyable both ways; racing is unwinnable and pointless.

## 6. Critic's dissent (summarised honestly)

The critic's core charge stands and this roadmap concedes it: the original 30-item validated list was a feature wishlist, not a strategy, and at solo-maintainer pace it represented ~3 years of work with no kill tier. Reliability was entirely absent despite being the top retention driver; it now leads. The critic also argued that Meeting Mode's proponents never asked whether Neuron Flame *wants* to be a recorder — no one has rebutted that, so it's cut rather than deferred. Two dissents are only partially resolved: the upstream-fork question is answered with a recommendation (hard divergence), not a decision — that call is Barney's alone and blocks the strategic bets; and the critic would likely say even this trimmed roadmap is 12+ months of solo work, which is true — sections 2 and 3 are the actual commitment, and section 4 is contingent on them landing without regressions. Finally, the critic's sharpest point deserves repeating verbatim in spirit: with GPL, the sustainable moat is polish and trust, not feature count — which is why the cheapest items on this list (crash recovery, paste fallback, key custody) are also the most important.
