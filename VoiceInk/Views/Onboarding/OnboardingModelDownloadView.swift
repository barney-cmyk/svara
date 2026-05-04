import SwiftUI

struct OnboardingModelDownloadView: View {
    @Binding var hasCompletedOnboarding: Bool
    // Parakeet V2 lives in the FluidAudio runtime, not Whisper. Both are needed
    // for the download flow + setting the default model.
    @EnvironmentObject private var fluidAudioModelManager: FluidAudioModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @State private var scale: CGFloat = 0.8
    @State private var opacity: CGFloat = 0
    @State private var isDownloading = false
    @State private var isModelSet = false
    @State private var showTutorial = false

    /// Parakeet V2 — NVIDIA's English-only 474 MB model, fastest streaming-capable
    /// option. Replaces the previous Whisper Large v3 Turbo (Quantized) default
    /// because Parakeet is what most users will actually want for live dictation.
    private let parakeetModel: FluidAudioModel = {
        TranscriptionModelRegistry.models.first {
            $0.name == "parakeet-tdt-0.6b-v2"
        } as! FluidAudioModel
    }()

    private var downloadFraction: Double {
        fluidAudioModelManager.downloadStatus(for: parakeetModel)?.fractionCompleted ?? 0
    }

    private var downloadStatusMessage: String {
        fluidAudioModelManager.downloadStatus(for: parakeetModel)?.message ?? "Downloading…"
    }

    var body: some View {
        ZStack {
            if showTutorial {
                OnboardingTutorialView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                GeometryReader { geometry in
                    OnboardingBackgroundView()

                    VStack(spacing: 40) {
                        // Model icon and title
                        VStack(spacing: 30) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                if isModelSet {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.accentColor)
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Image(systemName: "brain")
                                        .font(.system(size: 40))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .scaleEffect(scale)
                            .opacity(opacity)

                            VStack(spacing: 12) {
                                Text("Download AI Model")
                                    .font(.title2).fontWeight(.bold)
                                    .foregroundColor(.white)
                                Text("We'll download the optimized model to get you started.")
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            .scaleEffect(scale)
                            .opacity(opacity)
                        }

                        // Model card — centered, compact
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .center, spacing: 8) {
                                Text(parakeetModel.displayName)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(parakeetModel.size) • \(parakeetModel.language)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            .frame(maxWidth: .infinity)

                            Divider()
                                .background(Color.white.opacity(0.1))

                            HStack(spacing: 20) {
                                performanceIndicator(label: "Speed", value: parakeetModel.speed)
                                performanceIndicator(label: "Accuracy", value: parakeetModel.accuracy)
                                ramUsageLabel(gb: parakeetModel.ramUsage)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)

                            if isDownloading {
                                VStack(spacing: 6) {
                                    ProgressView(value: downloadFraction)
                                        .progressViewStyle(.linear)
                                        .tint(.accentColor)
                                    Text(downloadStatusMessage)
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .transition(.opacity)
                                .padding(.top, 4)
                            }
                        }
                        .padding(24)
                        .frame(width: min(geometry.size.width * 0.6, 400))
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .scaleEffect(scale)
                        .opacity(opacity)

                        // Action buttons
                        VStack(spacing: 16) {
                            Button(action: handleAction) {
                                Text(getButtonTitle())
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(width: 200, height: 50)
                                    .background(Color.accentColor)
                                    .cornerRadius(25)
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isDownloading)

                            if !isModelSet {
                                // No working model = the Try-It-Out tutorial physically
                                // can't dictate. Skip onboarding completely instead of
                                // routing to a broken tutorial; user picks a model later
                                // from the AI Models tab.
                                SkipButton(text: "Skip for now") {
                                    withAnimation { hasCompletedOnboarding = true }
                                }
                            }
                        }
                        .opacity(opacity)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .frame(width: min(geometry.size.width * 0.8, 600))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .onAppear {
            animateIn()
            checkModelStatus()
        }
    }

    private func animateIn() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            scale = 1
            opacity = 1
        }
    }

    private func checkModelStatus() {
        if fluidAudioModelManager.isFluidAudioModelDownloaded(parakeetModel) {
            isModelSet = transcriptionModelManager.currentTranscriptionModel?.name == parakeetModel.name
        }
    }

    private func handleAction() {
        if isModelSet {
            withAnimation { showTutorial = true }
            return
        }
        if fluidAudioModelManager.isFluidAudioModelDownloaded(parakeetModel) {
            // Already downloaded — just set as default.
            if let modelToSet = transcriptionModelManager.allAvailableModels.first(where: { $0.name == parakeetModel.name }) {
                transcriptionModelManager.setDefaultTranscriptionModel(modelToSet)
                withAnimation { isModelSet = true }
            }
            return
        }
        // Not downloaded — kick off download then set as default.
        withAnimation { isDownloading = true }
        Task {
            await fluidAudioModelManager.downloadFluidAudioModel(parakeetModel)
            if let modelToSet = transcriptionModelManager.allAvailableModels.first(where: { $0.name == parakeetModel.name }) {
                transcriptionModelManager.setDefaultTranscriptionModel(modelToSet)
                withAnimation {
                    isModelSet = true
                    isDownloading = false
                }
            } else {
                // Download finished but the model isn't visible in the registry yet.
                // Treat as a soft failure — let the user retry or skip.
                withAnimation { isDownloading = false }
            }
        }
    }

    private func getButtonTitle() -> String {
        if isModelSet { return "Continue" }
        if isDownloading { return "Downloading…" }
        if fluidAudioModelManager.isFluidAudioModelDownloaded(parakeetModel) {
            return "Set as Default"
        }
        return "Download Model"
    }

    private func performanceIndicator(label: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            HStack(spacing: 4) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(Double(index) / 5.0 <= value ? Color.accentColor : Color.white.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
        }
    }

    private func ramUsageLabel(gb: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RAM")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            Text(String(format: "%.1f GB", gb))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
        }
    }
}
