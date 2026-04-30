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
        URL(string: station.streamURL) != nil
    }

    func fetchTrack(for station: Station) async -> NowPlayingTrack? {
        guard let streamURL = URL(string: station.streamURL) else { return nil }

        var request = URLRequest(url: streamURL)
        request.timeoutInterval = 5
        request.setValue("1", forHTTPHeaderField: "Icy-MetaData")
        request.setValue("AVRadioMac/0.1", forHTTPHeaderField: "User-Agent")

        do {
            return try await parseICYTrack(from: request)
        } catch {
            return nil
        }
    }

    private func parseICYTrack(from request: URLRequest) async throws -> NowPlayingTrack? {
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
            if totalBytesRead > maxBytesToRead { return nil }

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
            if String(describing: key).caseInsensitiveCompare("icy-metaint") == .orderedSame {
                return Int(String(describing: value))
            }
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

        for separator in [" - ", " – ", " — "] where streamTitle.contains(separator) {
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
}
