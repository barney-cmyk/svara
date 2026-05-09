import SwiftUI

/// The About / "License" page.
///
/// Intentionally light on personal detail — the page is a manifesto for
/// Neuron Flame more than a developer bio. Three sections that matter:
///
///   1. **Mission** — why a free, on-device dictation app exists at all.
///      The thesis: typing has been a 50-year detour. Speech is closer to
///      thinking and to humans. Bringing speech back to the cursor matters.
///   2. **Privacy + infrastructure** — concrete claims (on-device, signed,
///      notarised, open-source) so the user can verify they're not being
///      surveilled.
///   3. **Updates + evaluation copy + donation** — the "WinRAR-style" social
///      contract: free forever, ship updates regularly, donate if it earns
///      its keep.
struct LicenseManagementView: View {
    @State private var pulse = false
    @State private var lastUpdateCheck: Date?
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                greeting
                missionCard
                privacyGrid
                updatesCard
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Hi.")
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

            Text("Neuron Flame is voice-to-text for macOS — built on the bet that speaking is closer to thinking than typing.")
                .font(.system(size: 15))
                .foregroundStyle(ZivaTheme.onSurface)
                .lineSpacing(4)
                .padding(.top, 4)

            Text("Free. On-device. Open source. An evaluation copy you can use forever.")
                .font(.system(size: 13))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .padding(.top, 2)
        }
    }

    // MARK: - Mission

    private var missionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("WHY THIS APP EXISTS")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(ZivaTheme.primary)

            Text("Speaking, again.")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(ZivaTheme.onSurface)

            Text("Humans spent two hundred thousand years talking to each other. We've spent the last fifty pecking at keyboards. The shift was practical — typing scaled, speaking didn't — but we've quietly traded warmth, nuance and conversational rhythm for a faster way to put words on a screen.")
                .font(.system(size: 14))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            Text("Local AI now transcribes faster than you can type. Neuron Flame's job is to put speech back where it belongs — at the cursor, in every app, without surveillance. Typing was always a detour. We're trying to make speaking the default again.")
                .font(.system(size: 14))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [ZivaTheme.primaryFixed.opacity(0.45), ZivaTheme.surfaceContainerLowest],
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

    // MARK: - Privacy + infrastructure grid

    private var privacyGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            statCard(
                icon: "lock.shield.fill",
                iconBg: ZivaTheme.secondaryContainer,
                iconColor: ZivaTheme.secondary,
                label: "TRANSCRIPTION",
                value: "100% local",
                hint: "Whisper or Parakeet V2 on your Apple Neural Engine. Audio never leaves the Mac."
            )

            statCard(
                icon: "checkmark.seal.fill",
                iconBg: ZivaTheme.tertiaryFixed,
                iconColor: ZivaTheme.tertiary,
                label: "DISTRIBUTION",
                value: "Apple-notarised",
                hint: "Signed with a registered Developer ID. Verified by Apple every time you launch."
            )

            statCard(
                icon: "eye.slash.fill",
                iconBg: ZivaTheme.primaryFixed,
                iconColor: ZivaTheme.primary,
                label: "TELEMETRY",
                value: "None",
                hint: "Zero analytics, zero phone-home. Open source under GPL-3 — auditable."
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
                    .font(.system(size: 20, weight: .bold))
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

    // MARK: - Updates card

    private var updatesCard: some View {
        HStack(alignment: .center, spacing: 20) {
            ZStack {
                Circle().fill(ZivaTheme.primaryFixed)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ZivaTheme.primary)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("STAY CURRENT")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)

                Text("Check for updates")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ZivaTheme.onSurface)

                Text("Currently running v\(appVersion). Updates ship signed and notarised — installed in place.")
                    .font(.system(size: 12))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                lastUpdateCheck = Date()
                updaterViewModel.checkForUpdates()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12))
                    Text("Check now").font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(ZivaTheme.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Donation / evaluation copy

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

            Text("Neuron Flame is free to use, share, and modify. It's an evaluation copy in the WinRAR sense — there's no paywall, no expiry, no nag. If it earns a place in your daily routine, a small thank-you via PayPal helps fund the time and infrastructure to keep shipping.")
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
                    let url = URL(string: "mailto:hello@neuronflame.com?subject=Hi%20from%20Neuron%20Flame")!
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
                Text("Built by Barney Sharma · GPL-3.0 · neuronflame.com")
                    .font(.system(size: 12))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                Spacer()
                Text("v\(appVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
            }
        }
        .padding(.top, 8)
    }
}
