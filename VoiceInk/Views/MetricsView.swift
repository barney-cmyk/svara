import SwiftUI
import SwiftData
import Charts
import KeyboardShortcuts

struct MetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @StateObject private var licenseViewModel = LicenseViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Status banner moved to the sidebar (ContentView). Dashboard now starts
            // with the metrics directly — fits in standard window real estate without scrolling.

            // Trial Message
            if case .trial(let daysRemaining) = licenseViewModel.licenseState {
                TrialMessageView(
                    message: "You have \(daysRemaining) days left in your trial",
                    type: daysRemaining <= 2 ? .warning : .info,
                    onAddLicenseKey: {
                        // Post notification to navigate to About tab
                        NotificationCenter.default.post(
                            name: .navigateToDestination,
                            object: nil,
                            userInfo: ["destination": "Pro"]
                        )
                    }
                )
                .padding()
            } else if case .trialExpired = licenseViewModel.licenseState {
                TrialMessageView(
                    message: "Your trial has expired. Upgrade to continue using Svara",
                    type: .expired,
                    onAddLicenseKey: {
                        // Also allow navigation from expired state
                        NotificationCenter.default.post(
                            name: .navigateToDestination,
                            object: nil,
                            userInfo: ["destination": "Pro"]
                        )
                    }
                )
                .padding()
            }

            MetricsContent(
                modelContext: modelContext,
                licenseState: licenseViewModel.licenseState
            )
        }
        .background(Color(.controlBackgroundColor))
    }
}
