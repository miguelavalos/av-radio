import Foundation

enum DiscoveryShareTextFormatter {
    static let title = "AV Radio discoveries"
    static let maxSharedDiscoveries = 25

    static func text(for discoveries: [DiscoveredTrack]) -> String {
        let lines = discoveries
            .filter { !$0.isHidden }
            .prefix(maxSharedDiscoveries)
            .map { discovery in
                [
                    AVRadioText.normalizedValue(discovery.artist),
                    AVRadioText.normalizedValue(discovery.title)
                ]
                .compactMap { $0 }
                .joined(separator: " - ")
            }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return "" }
        return ([title] + lines).joined(separator: "\n")
    }
}
