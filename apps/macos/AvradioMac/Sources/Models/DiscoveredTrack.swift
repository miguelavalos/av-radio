import Foundation

struct DiscoveredTrack: Identifiable, Hashable, Codable {
    let discoveryID: String
    var title: String
    var artist: String?
    var stationID: String
    var stationName: String
    var artworkURL: String?
    var stationArtworkURL: String?
    var playedAt: Date
    var markedInterestedAt: Date?
    var hiddenAt: Date?

    var id: String { discoveryID }

    init(
        title: String,
        artist: String?,
        station: Station,
        artworkURL: URL?,
        playedAt: Date = .now,
        markedInterestedAt: Date? = nil,
        hiddenAt: Date? = nil
    ) {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArtist = artist?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.discoveryID = Self.makeID(title: normalizedTitle, artist: normalizedArtist, stationID: station.id)
        self.title = normalizedTitle
        self.artist = normalizedArtist?.isEmpty == true ? nil : normalizedArtist
        self.stationID = station.id
        self.stationName = station.name
        self.artworkURL = artworkURL?.absoluteString
        self.stationArtworkURL = station.displayArtworkURL?.absoluteString
        self.playedAt = playedAt
        self.markedInterestedAt = markedInterestedAt
        self.hiddenAt = hiddenAt
    }

    var isMarkedInteresting: Bool {
        markedInterestedAt != nil
    }

    var isHidden: Bool {
        hiddenAt != nil
    }

    var artistDisplayText: String {
        artistNormalized ?? "Live now"
    }

    var searchQuery: String {
        if let artistNormalized {
            return "\(artistNormalized) \(title)"
        }
        return title
    }

    var resolvedArtworkURL: URL? {
        guard let artworkURL else { return nil }
        return URL(string: artworkURL)
    }

    var resolvedStationArtworkURL: URL? {
        guard let stationArtworkURL else { return nil }
        return URL(string: stationArtworkURL)
    }

    private var artistNormalized: String? {
        guard let artist else { return nil }
        let trimmed = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func makeID(title: String, artist: String?, stationID: String) -> String {
        let rawValue = "\(artist ?? "")|\(title)|\(stationID)"
        return rawValue
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "-" }
            .reduce(into: "") { result, character in
                if character != "-" || result.last != "-" {
                    result.append(character)
                }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }
}
