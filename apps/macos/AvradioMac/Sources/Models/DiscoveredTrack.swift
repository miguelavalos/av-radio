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
        let normalizedTitle = AVRadioDiscoveredTrackSupport.normalizedValue(title) ?? title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedArtist = AVRadioDiscoveredTrackSupport.normalizedValue(artist)
        self.discoveryID = Self.makeID(title: normalizedTitle, artist: normalizedArtist, stationID: station.id)
        self.title = normalizedTitle
        self.artist = normalizedArtist
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
        AVRadioDiscoveredTrackSupport.resolvedURL(artworkURL)
    }

    var resolvedStationArtworkURL: URL? {
        AVRadioDiscoveredTrackSupport.resolvedURL(stationArtworkURL)
    }

    private var artistNormalized: String? {
        AVRadioDiscoveredTrackSupport.normalizedValue(artist)
    }

    static func makeID(title: String, artist: String?, stationID: String) -> String {
        AVRadioDiscoveredTrackSupport.makeID(title: title, artist: artist, stationID: stationID)
    }
}
