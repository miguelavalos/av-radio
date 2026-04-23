import SwiftUI

struct ProfileSummaryRow: View {
    let preferredTag: String
    let appearanceMode: String
    let launchToSearch: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                summaryCards
            }

            VStack(spacing: 12) {
                summaryCards
            }
        }
    }

    @ViewBuilder
    private var summaryCards: some View {
        LibraryMetricCard(
            title: "Discovery",
            value: preferredTag.isEmpty ? "Default" : preferredTag.capitalized,
            detail: "Launch genre"
        )
        LibraryMetricCard(
            title: "Appearance",
            value: appearanceMode,
            detail: "Current mode"
        )
        LibraryMetricCard(
            title: "Start",
            value: launchToSearch ? "Search" : "Home",
            detail: "Launch destination"
        )
    }
}

struct LibrarySummaryRow: View {
    let favoritesCount: Int
    let recentsCount: Int
    let latestStationName: String?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                metricCards
            }

            VStack(spacing: 12) {
                metricCards
            }
        }
    }

    @ViewBuilder
    private var metricCards: some View {
        LibraryMetricCard(title: "Favorites", value: "\(favoritesCount)", detail: "Pinned stations")
        LibraryMetricCard(title: "Recents", value: "\(recentsCount)", detail: "Playback history")
        LibraryMetricCard(title: "Latest", value: latestStationName ?? "None", detail: "Most recent station")
    }
}

struct LibraryMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AvradioTheme.highlight)
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)
                .lineLimit(1)
            Text(detail)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)

                Text(subtitle)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                content
            }
        }
        .padding(22)
        .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
        }
    }
}

struct SettingsFieldRow<Content: View>: View {
    let title: String
    let description: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsLabel(title: title, description: description)
            content
        }
    }
}

struct SettingsLabel: View {
    let title: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AvradioTheme.textPrimary)

            Text(description)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
        }
    }
}

struct SettingsStatsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AvradioTheme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
        }
        .padding(.vertical, 2)
    }
}

enum HomeFeedContext {
    case popularWorldwide
    case popularInCountry(String)
}

struct CountryOption: Identifiable {
    let code: String
    let name: String

    var id: String { code }

    var flag: String? {
        guard code.count == 2 else { return nil }
        let base: UInt32 = 127397
        let scalars = code.uppercased().unicodeScalars.compactMap { UnicodeScalar(base + $0.value) }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    static let all: [CountryOption] = Locale.Region.isoRegions.compactMap { region in
        let code = region.identifier.uppercased()
        guard code.count == 2 else { return nil }
        return CountryOption(code: code, name: Locale.current.localizedString(forRegionCode: code) ?? code)
    }
    .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    static func name(for code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }
}

struct ShellHeader: View {
    let status: String

    var body: some View {
        HStack {
            HStack(spacing: 12) {
                Image("BrandMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                    .padding(10)
                    .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                    }

                (
                    Text("AV ").foregroundStyle(AvradioTheme.textPrimary) +
                    Text("Radio").foregroundStyle(AvradioTheme.highlight)
                )
                .font(.system(size: 22, weight: .bold))
            }

            Spacer()

            Text(status)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AvradioTheme.highlight)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AvradioTheme.cardSurface, in: Capsule())
                .overlay {
                    Capsule().stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        }
    }
}

struct SearchCountryFilterButton: View {
    let title: String
    let flag: String?
    let isActive: Bool
    let clearAction: () -> Void
    let openAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: openAction) {
                HStack(spacing: 8) {
                    Image(systemName: "globe.europe.africa")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Country")
                        .font(.system(size: 14, weight: .semibold))

                    if let flag {
                        Text(flag)
                            .font(.system(size: 16))
                    }

                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(isActive ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(isActive ? AvradioTheme.highlight.opacity(0.08) : AvradioTheme.cardSurface)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(isActive ? AvradioTheme.highlight.opacity(0.22) : AvradioTheme.borderSubtle, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if isActive {
                Button(action: clearAction) {
                    Text("Clear")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AvradioTheme.highlight)
                        .padding(.horizontal, 14)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(AvradioTheme.cardSurface)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct SearchCountryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedCountryCode: String?
    @State private var query = ""

    private var countryOptions: [CountryOption] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return CountryOption.all }
        return CountryOption.all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) ||
            $0.code.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("Search countries", text: $query)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        selectedCountryCode = nil
                        dismiss()
                    } label: {
                        CountryRow(
                            title: "All countries",
                            subtitle: "Use global discovery",
                            flag: nil,
                            isSelected: selectedCountryCode == nil
                        )
                    }
                    .buttonStyle(.plain)

                    ForEach(countryOptions) { option in
                        Button {
                            selectedCountryCode = option.code
                            dismiss()
                        } label: {
                            CountryRow(
                                title: option.name,
                                subtitle: nil,
                                flag: option.flag,
                                isSelected: selectedCountryCode == option.code
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
            .navigationTitle("Choose country")
        }
    }
}

struct CountryRow: View {
    let title: String
    let subtitle: String?
    let flag: String?
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AvradioTheme.highlight.opacity(0.12) : AvradioTheme.mutedSurface)

                if let flag {
                    Text(flag)
                        .font(.system(size: 22))
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AvradioTheme.highlight)
                }
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AvradioTheme.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AvradioTheme.highlight)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(
                            isSelected ? AvradioTheme.highlight.opacity(0.22) :
                                (isHovered ? AvradioTheme.highlight.opacity(0.14) : AvradioTheme.borderSubtle),
                            lineWidth: 1
                        )
                }
        )
        .shadow(color: isHovered ? AvradioTheme.softShadow.opacity(0.22) : .clear, radius: 10, y: 4)
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
