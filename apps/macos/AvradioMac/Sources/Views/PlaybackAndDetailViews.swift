import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let station: Station
    let openPlayer: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            StationArtworkView(station: station, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(station.name)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .foregroundStyle(AvradioTheme.textPrimary)
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)

                    Text(statusLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button {
                    audioPlayer.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(AvradioTheme.cardSurface, in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    audioPlayer.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(audioPlayer.isPlaying ? AvradioTheme.brandGraphite : AvradioTheme.highlight)

                        if audioPlayer.playbackState == .loading {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        } else {
                            Image(systemName: mainPlaybackSymbol)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 38, height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AvradioTheme.elevatedSurface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isHovered ? AvradioTheme.highlight.opacity(0.16) : AvradioTheme.glassStroke, lineWidth: 1)
        }
        .shadow(color: AvradioTheme.glassShadow.opacity(isHovered ? 0.9 : 0.7), radius: isHovered ? 12 : 8, y: isHovered ? 5 : 2)
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onTapGesture(perform: openPlayer)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private var mainPlaybackSymbol: String {
        switch audioPlayer.playbackState {
        case .playing:
            return "pause.fill"
        case .failed:
            return "arrow.clockwise"
        case .idle, .loading, .paused:
            return "play.fill"
        }
    }

    private var statusLine: String {
        switch audioPlayer.playbackState {
        case .idle:
            return station.shortMeta
        case .loading:
            return "Connecting stream..."
        case .playing:
            return "Live now · \(station.shortMeta)"
        case .paused:
            return "Paused · \(station.shortMeta)"
        case .failed(let message):
            return "Error · \(message)"
        }
    }

    private var statusColor: Color {
        switch audioPlayer.playbackState {
        case .playing:
            return AvradioTheme.highlight
        case .loading:
            return .orange
        case .failed:
            return .red
        case .idle, .paused:
            return AvradioTheme.textSecondary
        }
    }
}

struct MacNowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var libraryStore: LibraryStore

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height

            ZStack {
                AvradioTheme.onboardingBackground.ignoresSafeArea()

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [AvradioTheme.highlight.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 220
                        )
                    )
                    .frame(width: 420, height: 420)
                    .blur(radius: 20)
                    .offset(x: min(width * 0.24, 220), y: -min(height * 0.34, 260))

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.06), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180
                        )
                    )
                    .frame(width: 320, height: 320)
                    .blur(radius: 24)
                    .offset(x: -min(width * 0.2, 180), y: min(height * 0.34, 260))

                if let station = audioPlayer.currentStation {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            dismissBar
                                .padding(.top, topPadding(for: height))

                            if usesCompactLayout(for: width) {
                                compactNowPlayingLayout(for: station, width: width, height: height)
                            } else {
                                expandedNowPlayingLayout(for: station, width: width, height: height)
                            }
                        }
                        .padding(.horizontal, horizontalPadding(for: width))
                        .padding(.bottom, 36)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    EmptyStateCard(title: "Nothing playing", detail: "Start a station from Home or Search.")
                        .padding(40)
                }
            }
        }
    }

    private var dismissBar: some View {
        Button(action: dismiss.callAsFunction) {
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 54, height: 6)

                ZStack {
                    Text(audioPlayer.currentStation?.name ?? "Now Playing")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .padding(.horizontal, 44)
                        .frame(maxWidth: .infinity)

                    HStack {
                        Color.clear.frame(width: 34, height: 34)
                        Spacer()
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(AvradioTheme.textInverse.opacity(0.86))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.12), lineWidth: 1)
                            }
                    }
                }
                .frame(height: 34)
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 760)
    }

    private func heroArtwork(for station: Station, width: CGFloat) -> some View {
        let artworkSize = artworkDimension(for: width)

        return StationArtworkView(
            station: station,
            size: artworkSize,
            surfaceStyle: .dark,
            contentInsetRatio: 0.04,
            cornerRadiusRatio: 0.12
        )
        .background {
            Circle()
                .fill(AvradioTheme.highlight.opacity(0.22))
                .frame(width: artworkSize + 56, height: artworkSize + 56)
                .blur(radius: 34)
        }
        .shadow(color: AvradioTheme.highlight.opacity(0.18), radius: 26, y: 14)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    private func trackSummary(for station: Station, compact: Bool) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(station.shortMeta)
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Menu {
                    Button(libraryStore.isFavorite(station) ? "Remove Favorite" : "Add Favorite") {
                        libraryStore.toggleFavorite(station)
                    }

                    if let homepage = station.homepageURL, let url = URL(string: homepage) {
                        Button("Open Website") {
                            openURL(url)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse.opacity(0.78))
                        .rotationEffect(.degrees(90))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }

            Text(station.name)
                .font(.system(size: compact ? 28 : 32, weight: .black, design: .rounded))
                .foregroundStyle(AvradioTheme.textInverse)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(trackSubtitle(for: station))
                .font(compact ? .system(size: 14, weight: .medium) : .body)
                .foregroundStyle(AvradioTheme.textInverse.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(minHeight: compact ? 104 : 126, alignment: .topLeading)
    }

    private var transportSection: some View {
        HStack(spacing: 18) {
            compactTransportButton(systemImage: "stop.fill") {
                audioPlayer.stop()
            }

            Button {
                audioPlayer.togglePlayback()
            } label: {
                ZStack {
                    Circle()
                        .fill(AvradioTheme.highlight)
                        .shadow(color: AvradioTheme.highlight.opacity(0.25), radius: 18, y: 10)

                    if audioPlayer.playbackState == .loading {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(.white)
                    } else {
                        Image(systemName: mainTransportSymbol)
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 96, height: 96)
            }
            .buttonStyle(.plain)

            if case .failed = audioPlayer.playbackState {
                compactTransportButton(systemImage: "arrow.clockwise") {
                    audioPlayer.togglePlayback()
                }
            } else {
                compactTransportButton(systemImage: "dot.radiowaves.left.and.right") {}
                    .disabled(true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
        .frame(maxWidth: 760)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }

    private func statusSection(for station: Station) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                statusPill(text: playbackLabel)
                if let codec = station.codec, !codec.isEmpty {
                    statusPill(text: codec)
                }
                if let bitrate = station.bitrate {
                    statusPill(text: "\(bitrate) kbps")
                }
            }

            if let errorMessage = audioPlayer.lastErrorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(red: 1, green: 0.75, blue: 0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.red.opacity(0.18), lineWidth: 1)
                    }
            }

            if !station.tagsList.isEmpty {
                Text(station.tagsList.prefix(6).joined(separator: " · "))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AvradioTheme.textInverse.opacity(0.78))
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    private func statusPill(text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(AvradioTheme.textInverse.opacity(0.82))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func compactTransportButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AvradioTheme.textInverse.opacity(0.36))
                .frame(width: 60, height: 60)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: 60, height: 60)
        }
    }

    private var mainTransportSymbol: String {
        switch audioPlayer.playbackState {
        case .playing:
            return "pause.fill"
        case .failed:
            return "arrow.clockwise"
        case .idle, .loading, .paused:
            return "play.fill"
        }
    }

    private func trackSubtitle(for station: Station) -> String {
        if let homepage = station.homepageURL, !homepage.isEmpty {
            return "Streaming from \(homepage)"
        }
        return "Live stream active from \(station.name)"
    }

    private var playbackLabel: String {
        switch audioPlayer.playbackState {
        case .idle:
            return "Idle"
        case .loading:
            return "Loading"
        case .playing:
            return "Playing"
        case .paused:
            return "Paused"
        case .failed:
            return "Error"
        }
    }

    private func expandedNowPlayingLayout(for station: Station, width: CGFloat, height: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 34) {
            VStack(spacing: 22) {
                heroArtwork(for: station, width: width * 0.34)
                transportSection
            }
            .frame(maxWidth: 420)

            VStack(alignment: .leading, spacing: 22) {
                Spacer(minLength: max(12, height * 0.05))
                trackSummary(for: station, compact: false)
                statusSection(for: station)
                Spacer(minLength: 24)
            }
            .frame(maxWidth: 420, alignment: .leading)
        }
        .frame(maxWidth: 920, minHeight: max(460, height - 130), alignment: .center)
    }

    private func compactNowPlayingLayout(for station: Station, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 20) {
            heroArtwork(for: station, width: min(width - 72, 340))
                .padding(.top, 22)

            trackSummary(for: station, compact: true)

            VStack(spacing: 16) {
                transportSection
                statusSection(for: station)
            }
            .frame(maxWidth: 760)
        }
        .frame(maxWidth: min(width - 48, 760))
        .frame(minHeight: max(480, height - 120), alignment: .top)
    }

    private func usesCompactLayout(for width: CGFloat) -> Bool {
        width < 940
    }

    private func artworkDimension(for width: CGFloat) -> CGFloat {
        let boundedWidth = min(max(width, 220), 340)
        return boundedWidth
    }

    private func horizontalPadding(for width: CGFloat) -> CGFloat {
        max(24, min(42, width * 0.045))
    }

    private func topPadding(for height: CGFloat) -> CGFloat {
        max(18, min(28, height * 0.04))
    }
}

struct StationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let station: Station
    let isFavorite: Bool
    let isPlaying: Bool
    let playAction: () -> Void
    let toggleFavorite: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 16) {
                    StationArtworkView(station: station, size: 92)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(station.name)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(AvradioTheme.textPrimary)

                        if !station.detailLine.isEmpty {
                            Text(station.detailLine)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AvradioTheme.textSecondary)
                        }

                        if !station.tagsList.isEmpty {
                            Text(station.tagsList.prefix(4).joined(separator: " · "))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(AvradioTheme.highlight)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        playAction()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            Text(isPlaying ? "Playing" : "Play")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textPrimary)
                            .frame(width: 50, height: 50)
                            .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    if let homepageURL = station.homepageURL, let url = URL(string: homepageURL) {
                        Button {
                            openURL(url)
                        } label: {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(AvradioTheme.textPrimary)
                                .frame(width: 50, height: 50)
                                .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                DetailBlock(title: "About") {
                    DetailInfoRow(title: "Country", value: station.country)
                    DetailInfoRow(title: "Language", value: station.language)
                    if let state = station.state, !state.isEmpty {
                        DetailInfoRow(title: "State", value: state)
                    }
                    if let codec = station.codec, !codec.isEmpty {
                        DetailInfoRow(title: "Codec", value: codec)
                    }
                    if let bitrate = station.bitrate {
                        DetailInfoRow(title: "Bitrate", value: "\(bitrate) kbps")
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 560, minHeight: 440)
        .background(AvradioTheme.shellBackground)
    }
}

private struct DetailBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)

            VStack(spacing: 12) {
                content
            }
            .padding(18)
            .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
            }
        }
    }
}

private struct DetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AvradioTheme.textSecondary)
                .frame(width: 90, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AvradioTheme.textPrimary)

            Spacer()
        }
    }
}
