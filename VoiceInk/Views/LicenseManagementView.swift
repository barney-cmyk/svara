import SwiftUI

/// The About / "License" page.
///
/// **Layout intent:** everything fits in the visible viewport on a 950×730
/// window — no scrolling required for the user to see Updates, Donate, and
/// the privacy stats. Achieved by:
///   • a tight greeting + one-line mission statement (no separate "manifesto"
///     card — the dashboard already tells that story)
///   • compact privacy stat strip across the middle (3 cards, smaller pads)
///   • two-column row at the bottom: Updates + Donate side-by-side
///   • single-line footer
struct LicenseManagementView: View {
    @State private var pulse = false
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            greeting
            privacyGrid
            HStack(alignment: .top, spacing: 16) {
                updatesCard
                donationCard
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(.horizontal, 32)
        .padding(.top, 28)
        .padding(.bottom, 18)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(ZivaTheme.surface)
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Hi.")
                    .font(.system(size: 28, weight: .bold))
                    .tracking(-0.6)
                    .foregroundStyle(ZivaTheme.onSurface)

                Circle()
                    .fill(ZivaTheme.primary)
                    .frame(width: 7, height: 7)
                    .opacity(pulse ? 0.3 : 1.0)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    .padding(.bottom, 4)
                    .onAppear { pulse = true }

                Spacer(minLength: 0)
            }

            Text("Neuron Flame is voice-to-text for macOS — built on the bet that speaking is closer to thinking than typing.")
                .font(.system(size: 14))
                .foregroundStyle(ZivaTheme.onSurface)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text("Free. On-device. Open source. Use it for as long as you'd like.")
                .font(.system(size: 12))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
        }
    }

    // MARK: - Privacy + infrastructure grid

    private var privacyGrid: some View {
        HStack(alignment: .top, spacing: 12) {
            statCard(
                icon: "lock.shield.fill",
                iconBg: ZivaTheme.secondaryContainer,
                iconColor: ZivaTheme.secondary,
                label: "TRANSCRIPTION",
                value: "100% local",
                hint: "Whisper or Parakeet V2 on your Apple Neural Engine."
            )
            statCard(
                icon: "checkmark.seal.fill",
                iconBg: ZivaTheme.tertiaryFixed,
                iconColor: ZivaTheme.tertiary,
                label: "DISTRIBUTION",
                value: "Apple-notarised",
                hint: "Signed with a registered Developer ID."
            )
            statCard(
                icon: "eye.slash.fill",
                iconBg: ZivaTheme.primaryFixed,
                iconColor: ZivaTheme.primary,
                label: "TELEMETRY",
                value: "None",
                hint: "Zero analytics. Open source under GPL-3."
            )
        }
    }

    private func statCard(icon: String, iconBg: Color, iconColor: Color,
                          label: String, value: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(iconBg)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(iconColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(ZivaTheme.onSurfaceVariant)
                Text(value)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ZivaTheme.onSurface)
            }

            Text(hint)
                .font(.system(size: 11))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Updates card (left of bottom row)

    private var updatesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(ZivaTheme.primaryFixed)
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(ZivaTheme.primary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("STAY CURRENT")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(ZivaTheme.onSurfaceVariant)
                    Text("Check for updates")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZivaTheme.onSurface)
                }
                Spacer(minLength: 0)
            }

            Text("Currently running v\(appVersion). Updates ship signed and notarised — installed in place.")
                .font(.system(size: 11))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                updaterViewModel.checkForUpdates()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill").font(.system(size: 11))
                    Text("Check now").font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ZivaTheme.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ZivaTheme.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Donation card (right of bottom row)

    private var donationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(ZivaTheme.primaryFixed)
                    Image(systemName: "gift.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ZivaTheme.primary)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 1) {
                    Text("EVALUATION COPY")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(ZivaTheme.primary)
                    Text("Like what you see?")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ZivaTheme.onSurface)
                }
                Spacer(minLength: 0)
            }

            Text("Free to use, share, and modify. If it earns a place in your daily routine, a small thank-you helps keep things shipping.")
                .font(.system(size: 11))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button {
                    // PayPal.me — works with personal PayPal accounts and
                    // lands on a clean "send any amount" UI. The previous
                    // /donate/?business=<email> format needed donations
                    // explicitly enabled on a PayPal Business account, which
                    // Barney's personal account doesn't have, so it 404'd.
                    let url = URL(string: "https://paypal.me/neuronflame")!
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill").font(.system(size: 10))
                        Text("Donate").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(ZivaTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    let url = URL(string: "mailto:hello@neuronflame.com?subject=Hi%20from%20Neuron%20Flame")!
                    NSWorkspace.shared.open(url)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope.fill").font(.system(size: 10))
                        Text("Say hi").font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .foregroundStyle(ZivaTheme.primary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [ZivaTheme.primaryFixed.opacity(0.55), ZivaTheme.surfaceContainerLowest],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(ZivaTheme.outlineVariant, lineWidth: 1)
        )
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Built by Barney Sharma · GPL-3.0 · neuronflame.com")
                .font(.system(size: 11))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
            Spacer()
            Text("v\(appVersion)")
                .font(.system(size: 11))
                .foregroundStyle(ZivaTheme.onSurfaceVariant)
        }
        .padding(.top, 6)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(ZivaTheme.outlineVariant.opacity(0.5))
                .frame(height: 1)
        }
    }
}
