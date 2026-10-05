#if os(iOS) || os(macOS)
import SwiftUI
import UserNotifications

/// Notifications for new stories, per country.
struct AlertSettingsView: View {
    @State private var alerts = NewsAlerts.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        Form {
            Section {
                Toggle("Notify me about new stories", isOn: Binding(
                    get: { alerts.enabled },
                    set: { on in Task { await alerts.setEnabled(on) } }))
                if alerts.authorization == .denied {
                    Label("Notifications are turned off for Nordic Crypto in Settings.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(NL.warning)
                    #if os(iOS)
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    #endif
                }
            } footer: {
                Text(footer)
            }

            Section("Countries") {
                ForEach(Country.allCases) { country in
                    Toggle(isOn: Binding(get: { alerts.countries.contains(country.rawValue) },
                                         set: { _ in alerts.toggle(country) })) {
                        HStack(spacing: 12) {
                            CountryChip(code: country.rawValue)
                            Text(country.name)
                        }
                    }
                }
            }
            .disabled(!alerts.enabled)
        }
        .formStyle(.grouped)
        .navigationTitle("Notifications")
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
        }
        #endif
        .task { await alerts.refreshAuthorization() }
    }

    private var footer: LocalizedStringKey {
        #if os(macOS)
        "Nordic Crypto checks for new stories every 15 minutes while it runs, also from the menu bar. Nothing about you leaves this Mac."
        #else
        "Your iPhone or iPad checks for new stories in the background; iOS decides when, so a notification can come some time after a story is published. Nothing about you leaves the device."
        #endif
    }
}
#endif
