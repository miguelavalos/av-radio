import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var horizontalDragOffset: CGFloat = 0

    private let swipeThreshold: CGFloat = 72
    private let playerHorizontalPadding: CGFloat = 16
    private let playerMaxContentWidth: CGFloat = 360

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = playerContentWidth(in: proxy)
            let topInset = playerTopInset(in: proxy)

            ZStack(alignment: .top) {
                playerBackdrop

                VStack(spacing: 0) {
                    dismissBar(contentWidth: contentWidth)

                        VStack(spacing: 0) {
                            if let station = audioPlayer.currentStation {
                                artworkShowcase(for: station, size: contentWidth)
                                    .offset(x: horizontalDragOffset)
                                    .gesture(stationSwipeGesture)
                                    .padding(.top, 18)

                                trackSummary(for: station, contentWidth: contentWidth)
                                    .padding(.top, 18)

                                Spacer(minLength: 24)

                                VStack(spacing: 14) {
                                    transportSection(contentWidth: contentWidth)

                                    if shouldShowStatusRow {
                                        statusRow(contentWidth: contentWidth)
                                    }

                                    if audioPlayer.hasFailure {
                                        Button(L10n.string("player.retry"), action: audioPlayer.retry)
                                            .buttonStyle(.borderedProminent)
                                            .tint(AvradioTheme.highlight)
                                    }
                                }
                                .padding(.bottom, 36)
                            } else {
                                emptyState
                            }
                        }
                        .padding(.horizontal, playerHorizontalPadding)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.top, topInset)
            }
        }
        .ignoresSafeArea()
        .presentationDragIndicator(.hidden)
        .presentationBackground(.clear)
    }

    private var playerBackdrop: some View {
        ZStack {
            AvradioTheme.onboardingBackground.ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AvradioTheme.highlight.opacity(0.20), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 180
                    )
                )
                .frame(width: 360, height: 360)
                .blur(radius: 18)
                .offset(x: 118, y: -240)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [AvradioTheme.highlight.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 150
                    )
                )
                .frame(width: 300, height: 300)
                .blur(radius: 24)
                .offset(x: -150, y: 250)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.06), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 14)
                .offset(x: 54, y: 96)
        }
    }

    private func dismissBar(contentWidth: CGFloat) -> some View {
        Button(action: dismiss.callAsFunction) {
            VStack(spacing: 12) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 54, height: 6)

                ZStack {
                    Text(headerTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                        .padding(.horizontal, 44)
                        .frame(maxWidth: .infinity, alignment: .center)

                    HStack {
                        Color.clear
                            .frame(width: 34, height: 34)

                        Spacer()

                        Image(systemName: "chevron.down")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(AvradioTheme.textInverse.opacity(0.86))
                            .frame(width: 34, height: 34)
                            .background(Color.white.opacity(0.08), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
        .frame(width: contentWidth)
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("player.close.accessibility.label"))
        .accessibilityHint(L10n.string("player.close.accessibility.hint"))
    }

    private func artworkShowcase(for station: Station, size: CGFloat) -> some View {
        heroArtwork(for: station, size: size)
            .background {
                Circle()
                    .fill(AvradioTheme.highlight.opacity(0.22))
                    .frame(width: size + 56, height: size + 56)
                    .blur(radius: 34)
            }
            .overlay(alignment: .bottomLeading) {
                if audioPlayer.currentTrackArtworkURL != nil {
                    StationArtworkView(station: station, size: 58)
                        .padding(6)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                        .padding(18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func heroArtwork(for station: Station, size: CGFloat) -> some View {
        let cornerRadius: CGFloat = 32

        Group {
            if let artworkURL = audioPlayer.currentTrackArtworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        StationArtworkView(
                            station: station,
                            size: size,
                            contentInsetRatio: 0.04,
                            cornerRadiusRatio: cornerRadius / size
                        )
                    }
                }
            } else {
                StationArtworkView(
                    station: station,
                    size: size,
                    contentInsetRatio: 0.04,
                    cornerRadiusRatio: cornerRadius / size
                )
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if audioPlayer.currentTrackArtworkURL == nil {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            }
        }
        .shadow(color: AvradioTheme.highlight.opacity(0.18), radius: 26, y: 14)
        .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
    }

    private func trackSummary(for station: Station, contentWidth: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(trackArtistLine)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 12)

                optionsMenu(for: station)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(trackTitle(for: station))
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundStyle(AvradioTheme.textInverse)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let albumTitle = audioPlayer.currentTrackAlbumTitle {
                Text(albumTitle)
                    .font(.body)
                    .foregroundStyle(AvradioTheme.textInverse.opacity(0.74))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L10n.string("player.fromStation", station.name))
                    .font(.body)
                    .foregroundStyle(AvradioTheme.textInverse.opacity(0.68))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .padding(.top, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .frame(minHeight: 126, alignment: .topLeading)
    }

    private func transportSection(contentWidth: CGFloat) -> some View {
        HStack(spacing: 18) {
            compactTransportButton(systemImage: "backward.fill", action: playPreviousStation)
                .disabled(!canCycleStations)

            Button {
                audioPlayer.togglePlayback()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 96, height: 96)
                    .background(AvradioTheme.signalGradient, in: Circle())
                    .shadow(color: AvradioTheme.highlight.opacity(0.25), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isPlaying ? L10n.string("player.control.pause") : L10n.string("player.control.play"))

            compactTransportButton(systemImage: "forward.fill", action: playNextStation)
                .disabled(!canCycleStations)
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
        .frame(width: contentWidth)
        .shadow(color: .black.opacity(0.08), radius: 10, y: 6)
    }

    private func statusRow(contentWidth: CGFloat) -> some View {
        HStack {
            if let sleepTimerDescription = audioPlayer.sleepTimerDescription {
                statusPill(text: sleepTimerDescription)
            }
        }
        .frame(width: contentWidth, alignment: .leading)
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

    private func optionsMenu(for station: Station) -> some View {
        Menu {
            Button(libraryStore.isFavorite(station) ? L10n.string("player.menu.removeFavorite") : L10n.string("player.menu.addFavorite")) {
                libraryStore.toggleFavorite(for: station)
            }

            if let homepageURL {
                Button(L10n.string("player.menu.openWebsite")) {
                    openURL(homepageURL)
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

    private func compactTransportButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(canCycleStations ? AvradioTheme.textInverse : AvradioTheme.textInverse.opacity(0.36))
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

    private func playerContentWidth(in proxy: GeometryProxy) -> CGFloat {
        min(proxy.size.width - (playerHorizontalPadding * 2), playerMaxContentWidth)
    }

    private func playerTopInset(in proxy: GeometryProxy) -> CGFloat {
        max(64, proxy.safeAreaInsets.top + 10)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()

            Text(L10n.string("player.empty"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AvradioTheme.textInverse.opacity(0.84))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding(.horizontal, 28)
    }

    private var stationSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                guard canCycleStations, abs(value.translation.width) > abs(value.translation.height) else { return }
                horizontalDragOffset = value.translation.width * 0.24
            }
            .onEnded { value in
                guard canCycleStations else {
                    resetHorizontalDrag()
                    return
                }

                let isHorizontalSwipe = abs(value.translation.width) > abs(value.translation.height)
                let shouldAdvance = isHorizontalSwipe && value.translation.width <= -swipeThreshold
                let shouldReverse = isHorizontalSwipe && value.translation.width >= swipeThreshold

                if shouldAdvance {
                    playNextStation()
                } else if shouldReverse {
                    playPreviousStation()
                }

                resetHorizontalDrag()
            }
    }

    private var headerTitle: String {
        audioPlayer.currentStation?.name ?? L10n.string("player.header.nowPlaying")
    }

    private var trackArtistLine: String {
        audioPlayer.currentTrackArtist ?? L10n.string("player.track.liveNow")
    }

    private func trackTitle(for station: Station) -> String {
        if let title = audioPlayer.currentTrackTitle {
            return title
        }

        return audioPlayer.currentStation == nil ? L10n.string("player.track.pickStation") : L10n.string("player.track.liveStreamActive")
    }

    private var shouldShowStatusRow: Bool {
        audioPlayer.sleepTimerDescription != nil
    }

    private var homepageURL: URL? {
        guard let homepage = audioPlayer.currentStation?.homepageURL else { return nil }
        return URL(string: homepage)
    }

    private var cycleStations: [Station] {
        let favorites = libraryStore.favoriteStations()
        if favorites.count > 1,
           let current = audioPlayer.currentStation,
           favorites.contains(where: { $0.id == current.id }) {
            return favorites
        }

        let recents = libraryStore.recentStations()
        if recents.count > 1,
           let current = audioPlayer.currentStation,
           recents.contains(where: { $0.id == current.id }) {
            return recents
        }

        return []
    }

    private var canCycleStations: Bool {
        cycleStations.count > 1
    }

    private func playNextStation() {
        guard !cycleStations.isEmpty else { return }
        audioPlayer.playNext(from: cycleStations)
        recordCurrentPlayback()
    }

    private func playPreviousStation() {
        guard !cycleStations.isEmpty else { return }
        audioPlayer.playPrevious(from: cycleStations)
        recordCurrentPlayback()
    }

    private func recordCurrentPlayback() {
        guard let station = audioPlayer.currentStation else { return }
        libraryStore.recordPlayback(of: station)
    }

    private func resetHorizontalDrag() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            horizontalDragOffset = 0
        }
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(AudioPlayerService())
        .environmentObject(LibraryStore(container: PersistenceController(inMemory: true).container))
}
