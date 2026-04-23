import SwiftUI

struct SearchView: View {
    @Binding var query: String
    @Binding var activeTag: String?
    @Binding var selectedCountryCode: String?
    let results: [Station]
    let isLoading: Bool
    let errorMessage: String?
    let genreTags: [String]
    let playAction: (Station) -> Void
    let toggleFavorite: (Station) -> Void
    let isFavorite: (Station) -> Bool
    let showDetails: (Station) -> Void
    let searchAction: () -> Void
    @EnvironmentObject private var libraryStore: LibraryStore
    @State private var isShowingCountryPicker = false

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let compact = width < 820

            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 20 : 24) {
                    ShellHeader(status: isLoading ? "Searching" : "Search")
                    Text("Search")
                        .font(.system(size: compact ? 34 : 38, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)

                    if compact {
                        VStack(spacing: 12) {
                            searchBar
                            searchFilters
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 14) {
                            searchBar
                            searchFilters
                        }
                    }

                    StationSection(title: sectionTitle, subtitle: sectionSubtitle) {
                        if !results.isEmpty {
                            ForEach(results) { station in
                                StationRowCard(
                                    station: station,
                                    isFavorite: isFavorite(station),
                                    toggleFavorite: { toggleFavorite(station) },
                                    playAction: { playAction(station) },
                                    detailsAction: { showDetails(station) }
                                )
                            }
                        } else if isLoading {
                            EmptyStateCard(title: "Searching stations", detail: "Querying Radio Browser...")
                        } else if let errorMessage {
                            EmptyStateCard(title: "Search unavailable", detail: errorMessage)
                        } else {
                            EmptyStateCard(
                                title: "Nothing found",
                                detail: queryText.isEmpty && activeTag == nil
                                    ? "Pick a country or browse a genre tag."
                                    : "Try another query or clear some filters."
                            )
                        }
                    }
                }
                .frame(maxWidth: compact ? 760 : 1040, alignment: .leading)
                .padding(.horizontal, compact ? 20 : 28)
                .padding(.top, compact ? 22 : 28)
                .padding(.bottom, 120)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $isShowingCountryPicker) {
            SearchCountryPickerSheet(selectedCountryCode: $selectedCountryCode)
                .environmentObject(libraryStore)
        }
        .onChange(of: selectedCountryCode) { _, newValue in
            libraryStore.updatePreferredCountryCode(newValue)
        }
    }

    private var queryText: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var sectionTitle: String {
        if queryText.isEmpty && activeTag == nil && selectedCountryCode != nil {
            return "Popular in \(selectedCountryTitle)"
        }
        if queryText.isEmpty && activeTag == nil {
            return "Popular Worldwide"
        }
        if queryText.isEmpty {
            return "Browse"
        }
        return "Results"
    }

    private var sectionSubtitle: String {
        if let errorMessage {
            return errorMessage
        }
        if isLoading {
            return "Querying Radio Browser..."
        }
        if queryText.isEmpty {
            if let selectedCountryCode {
                return "Live stations for \(CountryOption(code: selectedCountryCode, name: selectedCountryTitle).name)."
            }
            if let activeTag {
                return "Browsing \(activeTag.capitalized) stations."
            }
            return "Browse the live catalogue by genre or country."
        }
        return "\(results.count) stations ready to play."
    }

    private var selectedCountryTitle: String {
        guard let selectedCountryCode else { return "All countries" }
        return CountryOption.name(for: selectedCountryCode)
    }

    private var selectedCountryFlag: String? {
        guard let selectedCountryCode else { return nil }
        return CountryOption(code: selectedCountryCode, name: selectedCountryTitle).flag
    }

    private func clearCountryFilter() {
        selectedCountryCode = nil
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            TextField("Artist, station, country or genre", text: $query)
                .textFieldStyle(.plain)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
                .onSubmit(searchAction)

            Button(action: searchAction) {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .tint(AvradioTheme.highlight)
        }
    }

    private var searchFilters: some View {
        VStack(alignment: .leading, spacing: 14) {
            SearchCountryFilterButton(
                title: selectedCountryTitle,
                flag: selectedCountryFlag,
                isActive: selectedCountryCode != nil,
                clearAction: clearCountryFilter,
                openAction: { isShowingCountryPicker = true }
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(genreTags, id: \.self) { tag in
                        Button {
                            activeTag = tag
                            query = tag
                            searchAction()
                        } label: {
                            Text(tag.capitalized)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(activeTag == tag ? AvradioTheme.highlight : AvradioTheme.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(activeTag == tag ? AvradioTheme.highlight.opacity(0.1) : AvradioTheme.cardSurface)
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(activeTag == tag ? AvradioTheme.highlight.opacity(0.22) : AvradioTheme.borderSubtle, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
