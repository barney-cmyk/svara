import SwiftUI

struct LicenseManagementView: View {
    @State private var pulse = false
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                greeting
                bentoGrid
                storyCallout
                donationCard
                footer
            }
            .padding(.horizontal, 40)
            .padding(.top, 48)
            .padding(.bottom, 56)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(ZivaTheme.surface)
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Hi, I'm Barney")
                    .font(.system(size: 32, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(ZivaTheme.onSurface)

                Circle()
                    .fill(ZivaTheme.primary)
                    .frame(width: 8, height: 8)
                    .opacity(pulse ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    .padding(.bottom, 6)
                    .onAppear { pulse = true }
            }

            Text("Neuron Flame by **Ziva Studio** — voice-to-text at the speed of thought.")
                .font(.system(size: 14))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(3)

            Text("Named after my daughter Ziva. *Neuron Flame* is Sanskrit for the tone — the note that turns sound into meaning. That's exactly what this app captures.")
                .font(.system(size: 13))
                .foregroundStyle(ZivaTheme.onSurfaceVariant.opacity(0.85))
                .lineSpacing(4)
                .padding(.top, 2)
        }
    }

    // MARK: - Bento grid

    private var bentoGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            statCard(
                icon: "sparkles",
                iconBg: ZivaTheme.primaryFixed,
                iconColor: ZivaTheme.primary,
                label: "BUILT WITH",
                value: "AI",
                hint: "From zero to working app, with AI as my teacher."
            )

            statCard(
                icon: "lock.fill",
                iconBg: ZivaTheme.secondaryContainer,
                iconColor: ZivaTheme.secondary,
                label: "PRIVACY",
                value: "100% Local",
                hint: "Your voice never leaves this Mac."
            )

            statCard(
                icon: "heart.fill",
                iconBg: ZivaTheme.tertiaryFixed,
                iconColor: ZivaTheme.tertiary,
                label: "FOR",
                value: "Ziva",
                hint: "Named after my daughter."
            )
        }
    }

    private func statCard(icon: String, iconBg: Color, iconColor: Color,
                          label: String, value: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)

                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(ZivaTheme.onSurface)
            }

            Text(hint)
                .font(.system(size: 12))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Story callout

    private var storyCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A SMALL NOTE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(ZivaTheme.onSurfaceVariant)

            Text("AI is the great equalizer of our time. If I can build software, you can build whatever you've been dreaming of. Don't wait for permission — start now.")
                .font(.system(size: 16, weight: .regular))
                .italic()
                .foregroundStyle(ZivaTheme.onSurface)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Donation card (WinRAR-style evaluation)

    private var donationCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(ZivaTheme.primaryFixed)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(ZivaTheme.primary)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("EVALUATION COPY")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(ZivaTheme.primary)

                    Text("Like what you see?")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(ZivaTheme.onSurface)
                }
            }

            Text("Neuron Flame is free to use, share, and modify. If it's earned a place in your daily routine, you can send a small thank-you via PayPal. No obligation — never has been, never will be.")
                .font(.system(size: 14))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    let url = URL(string: "https://www.paypal.com/donate/?business=barney%40theaussiesharmas.com.au&item_name=Neuron+Flame+thank-you&currency_code=AUD")!
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "heart.fill").font(.system(size: 12))
                        Text("Donate via PayPal").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(ZivaTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    let url = URL(string: "mailto:barney@theaussiesharmas.com.au?subject=Hi%20from%20Ziva%20AI")!
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope.fill").font(.system(size: 12))
                        Text("Say hi").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .foregroundStyle(ZivaTheme.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [ZivaTheme.primaryFixed.opacity(0.55), ZivaTheme.surfaceContainerLowest],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(ZivaTheme.outlineVariant.opacity(0.6))
                .frame(height: 1)
                .padding(.bottom, 16)

            HStack {
                Text("Made by Barney Sharma · For Ziva")
                    .font(.system(size: 12))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                Spacer()
                Text("v\(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
            }
        }
        .padding(.top, 16)
    }
}
