import Foundation

struct AVRadioNowPlayingTrack: Equatable, Sendable {
    let title: String
    let artist: String?
}

enum AVRadioNowPlayingMetadata {
    static func metadataInterval(from response: HTTPURLResponse) -> Int? {
        for (key, value) in response.allHeaderFields {
            guard String(describing: key).caseInsensitiveCompare("icy-metaint") == .orderedSame else {
                continue
            }
            return Int(String(describing: value))
        }

        return nil
    }

    static func parseICYMetadata(_ bytes: [UInt8]) -> AVRadioNowPlayingTrack? {
        let metadata = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .controlCharacters.union(.whitespacesAndNewlines))
            .replacingOccurrences(of: "\0", with: "")

        guard let streamTitle = metadataValue(named: "StreamTitle", in: metadata), !streamTitle.isEmpty else {
            return nil
        }

        return AVRadioTrackMetadataParser.parse(streamTitle).nowPlayingTrack
    }

    private static func metadataValue(named name: String, in metadata: String) -> String? {
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

struct AVRadioTrackMetadata: Equatable, Sendable {
    var title: String?
    var artist: String?
}

enum AVRadioTrackMetadataParser {
    static func parse(_ rawValue: String) -> AVRadioTrackMetadata {
        let cleaned = rawValue
            .replacingOccurrences(of: "StreamTitle=", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "'; ").union(.whitespacesAndNewlines))

        for separator in [" - ", " – ", " — "] where cleaned.contains(separator) {
            let parts = cleaned.components(separatedBy: separator)
            guard parts.count >= 2 else { continue }

            let artist = sanitizeArtist(parts[0])
            let title = sanitizeTitle(parts.dropFirst().joined(separator: separator), artist: artist)
            return AVRadioTrackMetadata(title: title, artist: artist)
        }

        return AVRadioTrackMetadata(title: sanitizeTitle(cleaned, artist: nil), artist: nil)
    }

    static func sanitizeTitle(_ rawValue: String?, artist: String?) -> String? {
        guard var value = sanitizeMetadataField(rawValue) else { return nil }

        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if containsLetters(value) {
            return value
        }

        if isNumericOnlyMetadata(value) {
            let digits = value.filter(\.isNumber).count

            // Large numeric-only metadata values are typically IDs, not song titles.
            if digits > 4 {
                return nil
            }

            // Short numeric titles can be legitimate, but not without a plausible artist.
            return artist == nil ? nil : value
        }

        return nil
    }

    static func sanitizeArtist(_ rawValue: String?) -> String? {
        guard var value = sanitizeMetadataField(rawValue) else { return nil }

        value = value.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return containsLetters(value) ? value : nil
    }

    private static func sanitizeMetadataField(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue
            .trimmingCharacters(in: CharacterSet(charactersIn: "'; ").union(.whitespacesAndNewlines))

        guard !trimmed.isEmpty else { return nil }

        let blockedValues: Set<String> = ["unknown", "n/a", "na", "null", "nil", "-", "--"]
        guard !blockedValues.contains(trimmed.lowercased()) else { return nil }

        return trimmed
    }

    private static func containsLetters(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    private static func isNumericOnlyMetadata(_ value: String) -> Bool {
        let filtered = value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        guard !filtered.isEmpty else { return false }
        return filtered.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }
}

private extension AVRadioTrackMetadata {
    var nowPlayingTrack: AVRadioNowPlayingTrack? {
        guard let title else { return nil }
        return AVRadioNowPlayingTrack(title: title, artist: artist)
    }
}
