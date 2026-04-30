import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var libraryStore: LibraryStore
    @AppStorage("avradio.mac.appearance") private var appearanceMode = "system"
    @AppStorage("avradio.mac.launchToSearch") private var launchToSearch = false

    var body: some View {
        Form {
            Section("Discovery") {
                TextField(
                    "Preferred discovery tag",
                    text: Binding(
                        get: { libraryStore.preferredTag },
                        set: { libraryStore.updatePreferredTag($0) }
                    )
                )

                Toggle("Open directly in Search", isOn: $launchToSearch)
            }

            Section("Appearance") {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Access") {
                Picker("Mode", selection: Binding(
                    get: { libraryStore.accessMode },
                    set: { libraryStore.updateAccessMode($0) }
                )) {
                    ForEach(AccessMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Cloud sync", value: libraryStore.capabilities.canUseCloudSync ? "Enabled for Pro" : "Pro only")
                LabeledContent("Favorites", value: limitText(libraryStore.limits.favoriteStations))
                LabeledContent("Music lookups", value: libraryStore.capabilities.canAccessPremiumFeatures ? "Practical unlimited" : "Limited daily")
            }

            Section("Local Data") {
                Button("Clear local library", role: .destructive) {
                    libraryStore.clearLocalState()
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 440)
    }

    private func limitText(_ limit: Int?) -> String {
        limit.map(String.init) ?? "Practical unlimited"
    }
}
