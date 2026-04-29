import Foundation

struct NowPlayingTrack: Equatable, Sendable {
    let title: String
    let artist: String?
}

actor NowPlayingService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    nonisolated func supports(_ station: Station) -> Bool {
        provider(for: station) != nil
    }

    func fetchTrack(for station: Station) async -> NowPlayingTrack? {
        guard let provider = provider(for: station) else { return nil }

        do {
            return try await provider.fetchTrack(for: station, using: session)
        } catch {
            return nil
        }
    }

    private nonisolated func provider(for station: Station) -> Provider? {
        let homepageHost = URL(string: station.homepageURL ?? "")?.host?.lowercased()
        let streamHost = URL(string: station.streamURL)?.host?.lowercased()

        if homepageHost?.contains("80s80s.de") == true || streamHost?.contains("80s80s") == true {
            return .eighties80s
        }

        if URL(string: station.streamURL) != nil {
            return .icyStream
        }

        return nil
    }
}

private extension NowPlayingService {
    enum Provider {
        case eighties80s
        case icyStream

        func fetchTrack(for station: Station, using session: URLSession) async throws -> NowPlayingTrack? {
            switch self {
            case .eighties80s:
                return try await fetch80s80sTrack(for: station, using: session)
            case .icyStream:
                return try await fetchICYTrack(for: station, using: session)
            }
        }

        private func fetchICYTrack(for station: Station, using session: URLSession) async throws -> NowPlayingTrack? {
            guard let streamURL = URL(string: station.streamURL) else { return nil }

            var request = URLRequest(url: streamURL)
            request.timeoutInterval = 5
            request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
            request.setValue("AVRadio/0.1", forHTTPHeaderField: "User-Agent")

            return try await parseICYTrack(from: request, using: session)
        }

        private func parseICYTrack(from request: URLRequest, using session: URLSession) async throws -> NowPlayingTrack? {
            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<400 ~= httpResponse.statusCode else {
                return nil
            }

            guard let metadataInterval = metadataInterval(from: httpResponse), metadataInterval > 0 else {
                return nil
            }

            var bytesUntilMetadata = metadataInterval
            var totalBytesRead = 0
            let maxBytesToRead = min(metadataInterval + 4096, 262_144)
            var iterator = bytes.makeAsyncIterator()

            while let byte = try await iterator.next() {
                if Task.isCancelled { return nil }

                totalBytesRead += 1
                if totalBytesRead > maxBytesToRead {
                    return nil
                }

                if bytesUntilMetadata > 0 {
                    bytesUntilMetadata -= 1
                    continue
                }

                let metadataLength = Int(byte) * 16
                guard metadataLength > 0 else {
                    bytesUntilMetadata = metadataInterval
                    continue
                }

                var metadataBytes: [UInt8] = []
                metadataBytes.reserveCapacity(metadataLength)

                for _ in 0..<metadataLength {
                    guard let metadataByte = try await iterator.next() else { return nil }
                    metadataBytes.append(metadataByte)
                }

                if let track = parseICYMetadata(metadataBytes) {
                    return track
                }

                bytesUntilMetadata = metadataInterval
            }

            return nil
        }

        private func metadataInterval(from response: HTTPURLResponse) -> Int? {
            for (key, value) in response.allHeaderFields {
                guard String(describing: key).caseInsensitiveCompare("icy-metaint") == .orderedSame else {
                    continue
                }
                return Int(String(describing: value))
            }

            return nil
        }

        private func parseICYMetadata(_ bytes: [UInt8]) -> NowPlayingTrack? {
            let metadata = String(decoding: bytes, as: UTF8.self)
                .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
                .replacingOccurrences(of: "\0", with: "")

            guard let streamTitle = metadataValue(named: "StreamTitle", in: metadata), !streamTitle.isEmpty else {
                return nil
            }

            let separators = [" - ", " – ", " — "]
            for separator in separators where streamTitle.contains(separator) {
                let parts = streamTitle.components(separatedBy: separator)
                guard parts.count >= 2 else { continue }

                let artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let title = parts.dropFirst().joined(separator: separator).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !title.isEmpty else { continue }

                return NowPlayingTrack(title: title, artist: artist.isEmpty ? nil : artist)
            }

            return NowPlayingTrack(title: streamTitle, artist: nil)
        }

        private func metadataValue(named name: String, in metadata: String) -> String? {
            let pattern = "\(name)='([^']*)'"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return nil
            }

            let nsRange = NSRange(metadata.startIndex..<metadata.endIndex, in: metadata)
            guard
                let match = regex.firstMatch(in: metadata, range: nsRange),
                let valueRange = Range(match.range(at: 1), in: metadata)
            else {
                return nil
            }

            return String(metadata[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        private func fetch80s80sTrack(for station: Station, using session: URLSession) async throws -> NowPlayingTrack? {
            let requestURL = resolved80s80sURL(for: station) ?? URL(string: "https://www.80s80s.de/80s80s-app")!
            var request = URLRequest(url: requestURL)
            request.timeoutInterval = 10
            request.setValue("AVRadio/0.1", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                return nil
            }

            let html = String(decoding: data, as: UTF8.self)
            return parse80s80sTrack(for: station, from: html)
        }

        private func resolved80s80sURL(for station: Station) -> URL? {
            guard let homepageURL = URL(string: station.homepageURL ?? "") else { return nil }
            let host = homepageURL.host?.lowercased() ?? ""
            guard host.contains("80s80s.de") else { return nil }
            return homepageURL
        }

        private func parse80s80sTrack(for station: Station, from html: String) -> NowPlayingTrack? {
            let entries = parse80s80sEntries(from: html)
            guard let entry = best80s80sEntry(for: station, in: entries) else { return nil }

            return NowPlayingTrack(title: entry.songTitle, artist: entry.artistName)
        }

        private func parse80s80sEntries(from html: String) -> [Eighties80sEntry] {
            let pattern = #"(stream|song_title|artist_name):"([^"]+)""#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

            let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
            var currentStream: String?
            var currentTitle: String?
            var currentArtist: String?
            var entries: [Eighties80sEntry] = []

            regex.enumerateMatches(in: html, options: [], range: nsRange) { match, _, _ in
                guard
                    let match,
                    let keyRange = Range(match.range(at: 1), in: html),
                    let valueRange = Range(match.range(at: 2), in: html)
                else {
                    return
                }

                let key = String(html[keyRange])
                let value = String(html[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)

                switch key {
                case "stream":
                    if let currentStream, let currentTitle, !currentTitle.isEmpty {
                        entries.append(
                            Eighties80sEntry(
                                streamName: currentStream,
                                songTitle: currentTitle,
                                artistName: currentArtist
                            )
                        )
                    }
                    currentStream = value
                    currentTitle = nil
                    currentArtist = nil
                case "song_title":
                    currentTitle = value
                case "artist_name":
                    currentArtist = value
                default:
                    break
                }
            }

            if let currentStream, let currentTitle, !currentTitle.isEmpty {
                entries.append(
                    Eighties80sEntry(
                        streamName: currentStream,
                        songTitle: currentTitle,
                        artistName: currentArtist
                    )
                )
            }

            return entries
        }

        private func best80s80sEntry(for station: Station, in entries: [Eighties80sEntry]) -> Eighties80sEntry? {
            let stationKeys = stationKeysFor80s80s(station)

            return entries
                .compactMap { entry in
                    let score = score80s80sEntry(entry, stationKeys: stationKeys)
                    return score > 0 ? (score, entry) : nil
                }
                .max { lhs, rhs in lhs.0 < rhs.0 }?
                .1
        }

        private func stationKeysFor80s80s(_ station: Station) -> Set<String> {
            var keys: Set<String> = []
            let normalizedStationName = normalize80s80sToken(station.name)
            if !normalizedStationName.isEmpty {
                keys.insert(normalizedStationName)
            }

            if let homepageURL = URL(string: station.homepageURL ?? "") {
                let slug = homepageURL.lastPathComponent
                let normalizedSlug = normalize80s80sToken(slug)
                if !normalizedSlug.isEmpty {
                    keys.insert(normalizedSlug)
                }
            }

            let lowercasedName = station.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            if normalizedStationName.isEmpty || normalizedStationName == "RADIO" || lowercasedName == "80s80s" {
                keys.insert("LIVE")
            }

            if lowercasedName.contains("depeche mode") {
                keys.insert("DM")
            }

            return keys
        }

        private func score80s80sEntry(_ entry: Eighties80sEntry, stationKeys: Set<String>) -> Int {
            let normalizedStream = normalize80s80sToken(entry.streamName)

            if stationKeys.contains(normalizedStream) {
                return 100
            }

            if stationKeys.contains(where: { key in
                !key.isEmpty && (normalizedStream.contains(key) || key.contains(normalizedStream))
            }) {
                return 70
            }

            return 0
        }

        private func normalize80s80sToken(_ rawValue: String) -> String {
            let uppercased = rawValue
                .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .uppercased()

            let withoutPrefix = uppercased.replacingOccurrences(of: "80S80S", with: " ")
            let filteredScalars = withoutPrefix.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
            return String(String.UnicodeScalarView(filteredScalars))
        }
    }

    struct Eighties80sEntry: Equatable {
        let streamName: String
        let songTitle: String
        let artistName: String?
    }
}
