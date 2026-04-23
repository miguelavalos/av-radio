import SwiftUI

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var audioPlayer: AudioPlayerService
    @EnvironmentObject private var libraryStore: LibraryStore

    @State private var horizontalDragOffset: CGFloat = 0

    private let swipeThreshold: CGFloat = 72
    private let playerHorizontalPadding: CGFloat = 16
    private let playerLandscapeHorizontalPadding: CGFloat = 12
    private let playerMaxContentWidth: CGFloat = 360
    private let playerMaxLandscapeContentWidth: CGFloat = 860

    var body: some View {
        GeometryReader { proxy in
            let isLandscape = usesLandscapeLayout(in: proxy)
            let horizontalInsets = playerHorizontalInsets(in: proxy, isLandscape: isLandscape)
            let contentWidth = playerContentWidth(in: proxy, isLandscape: isLandscape, horizontalInsets: horizontalInsets)
            let topInset = playerTopInset(in: proxy, isLandscape: isLandscape)
            let bottomInset = playerBottomInset(
                in: proxy,
                isLandscape: isLandscape,
                horizontalInsets: horizontalInsets,
                contentWidth: contentWidth
            )
            let contentHeight = playerContentHeight(
                in: proxy,
                isLandscape: isLandscape,
                topInset: topInset,
                bottomInset: bottomInset
            )

            ZStack(alignment: .top) {
                playerBackdrop

                VStack(spacing: 0) {
                    dismissBar()

                    playerContent(
                        in: proxy,
                        isLandscape: isLandscape,
                        contentWidth: contentWidth,
                        contentHeight: contentHeight
                    )
                }
                .frame(width: contentWidth, alignment: .top)
                .padding(.leading, horizontalInsets.leading)
                .padding(.trailing, horizontalInsets.trailing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, topInset)
                .padding(.bottom, bottomInset)
            }
        }
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

    private func dismissBar() -> some View {
        Button(action: dismiss.callAsFunction) {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 54, height: 6)
                    .padding(.top, 10)

                ZStack {
                    Text(headerTitle)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                        .padding(.horizontal, 44)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityIdentifier("player.headerTitle")

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
                .frame(height: 44)
                .padding(.top, 22)
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .frame(height: 84)
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
        .accessibilityLabel(L10n.string("player.close.accessibility.label"))
        .accessibilityHint(L10n.string("player.close.accessibility.hint"))
        .accessibilityIdentifier("player.close")
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
                    stationBadgeArtwork(for: station, size: 58)
                        .padding(18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func stationBadgeArtwork(for station: Station, size: CGFloat) -> some View {
        let badgeCornerRadius: CGFloat = 16

        Group {
            if let artworkURL = stationArtworkURL(for: station) {
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
                            surfaceStyle: .light,
                            contentInsetRatio: 0.04,
                            cornerRadiusRatio: badgeCornerRadius / size
                        )
                    }
                }
            } else {
                StationArtworkView(
                    station: station,
                    size: size,
                    surfaceStyle: .light,
                    contentInsetRatio: 0.04,
                    cornerRadiusRatio: badgeCornerRadius / size
                )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: badgeCornerRadius, style: .continuous))
        .padding(1)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: badgeCornerRadius + 3, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: badgeCornerRadius + 3, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }

    @ViewBuilder
    private func playerContent(
        in proxy: GeometryProxy,
        isLandscape: Bool,
        contentWidth: CGFloat,
        contentHeight: CGFloat
    ) -> some View {
        if let station = audioPlayer.currentStation {
            let compact = isCompactPlayer(in: proxy, isLandscape: isLandscape)

            if isLandscape {
                landscapePlayerContent(
                    for: station,
                    in: proxy,
                    contentWidth: contentWidth,
                    contentHeight: contentHeight,
                    compact: compact
                )
            } else {
                portraitPlayerContent(
                    for: station,
                    in: proxy,
                    contentWidth: contentWidth,
                    contentHeight: contentHeight,
                    compact: compact
                )
            }
        } else {
            emptyState
                .frame(maxHeight: .infinity)
        }
    }

    private func portraitPlayerContent(
        for station: Station,
        in proxy: GeometryProxy,
        contentWidth: CGFloat,
        contentHeight: CGFloat,
        compact: Bool
    ) -> some View {
        let artworkSize = portraitArtworkSize(in: proxy, contentWidth: contentWidth, compact: compact)
        let summaryTopPadding: CGFloat = compact ? 16 : 18
        let spacerMinLength: CGFloat = compact ? 18 : 24

        return VStack(spacing: 0) {
            artworkShowcase(for: station, size: artworkSize)
                .offset(x: horizontalDragOffset)
                .gesture(stationSwipeGesture)
                .padding(.top, 18)

            trackSummary(for: station, contentWidth: contentWidth, compact: compact)
                .padding(.top, summaryTopPadding)

            Spacer(minLength: spacerMinLength)

            playerControls(contentWidth: contentWidth, compact: compact)
        }
        .frame(height: contentHeight, alignment: .top)
    }

    private func landscapePlayerContent(
        for station: Station,
        in proxy: GeometryProxy,
        contentWidth: CGFloat,
        contentHeight: CGFloat,
        compact: Bool
    ) -> some View {
        let artworkSize = landscapeArtworkSize(in: proxy, contentWidth: contentWidth)
        let columnSpacing: CGFloat = compact ? 22 : 28
        let detailWidth = max(contentWidth - artworkSize - columnSpacing, 260)
        let summaryHeight: CGFloat = compact ? 74 : 88

        return VStack(spacing: 0) {
            LandscapeNowPlayingRowLayout(
                artworkSize: artworkSize,
                spacing: columnSpacing,
                summaryHeight: summaryHeight
            ) {
                artworkShowcase(for: station, size: artworkSize)
                    .frame(width: artworkSize)
                    .offset(x: horizontalDragOffset)
                    .gesture(stationSwipeGesture)

                trackSummary(
                    for: station,
                    contentWidth: detailWidth,
                    minHeight: summaryHeight,
                    compact: compact
                )

                playerControls(contentWidth: detailWidth, compact: compact)
            }
            .frame(width: contentWidth, height: artworkSize)
            .padding(.top, compact ? 8 : 12)

            Spacer(minLength: 0)
        }
        .frame(height: contentHeight, alignment: .top)
    }

    @ViewBuilder
    private func heroArtwork(for station: Station, size: CGFloat) -> some View {
        let cornerRadius: CGFloat = 32
        let heroArtworkURL = audioPlayer.currentTrackArtworkURL ?? stationArtworkURL(for: station)

        Group {
            if let heroArtworkURL {
                AsyncImage(url: heroArtworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .scaleEffect(1.24)
                            .clipped()
                    default:
                        StationArtworkView(
                            station: station,
                            size: size,
                            surfaceStyle: .dark,
                            contentInsetRatio: 0.04,
                            cornerRadiusRatio: cornerRadius / size
                        )
                    }
                }
            } else {
                StationArtworkView(
                    station: station,
                    size: size,
                    surfaceStyle: .dark,
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

    private func trackSummary(
        for station: Station,
        contentWidth: CGFloat,
        minHeight: CGFloat = 126,
        compact: Bool = false
    ) -> some View {
        VStack(spacing: compact ? 6 : 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(trackArtistLine)
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 12)

                optionsMenu(for: station)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(trackTitle(for: station))
                .font(.system(size: compact ? 21 : 25, weight: .black, design: .rounded))
                .foregroundStyle(AvradioTheme.textInverse)
                .multilineTextAlignment(.leading)
                .lineLimit(compact ? 2 : 3)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let albumTitle = audioPlayer.currentTrackAlbumTitle {
                Text(albumTitle)
                    .font(compact ? .subheadline : .body)
                    .foregroundStyle(AvradioTheme.textInverse.opacity(0.74))
                    .multilineTextAlignment(.leading)
                    .lineLimit(compact ? 1 : 2)
                    .padding(.top, compact ? 0 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(L10n.string("player.fromStation", station.name))
                    .font(compact ? .subheadline : .body)
                    .foregroundStyle(AvradioTheme.textInverse.opacity(0.68))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .padding(.top, compact ? 0 : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: contentWidth, alignment: .leading)
        .frame(minHeight: minHeight, alignment: .topLeading)
    }

    private func playerControls(contentWidth: CGFloat, compact: Bool) -> some View {
        VStack(spacing: compact ? 10 : 14) {
            transportSection(contentWidth: contentWidth, compact: compact)

            if shouldShowStatusRow {
                statusRow(contentWidth: contentWidth)
            }

            retrySection
        }
    }

    private func transportSection(contentWidth: CGFloat, compact: Bool) -> some View {
        let sideButtonSize: CGFloat = compact ? 52 : 60
        let primaryButtonSize: CGFloat = compact ? 84 : 96

        return HStack(spacing: compact ? 14 : 18) {
            compactTransportButton(systemImage: "backward.fill", size: sideButtonSize, compact: compact, action: playPreviousStation)
                .disabled(!canCycleStations)

            Button {
                audioPlayer.togglePlayback()
            } label: {
                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: compact ? 28 : 32, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: primaryButtonSize, height: primaryButtonSize)
                    .background(AvradioTheme.signalGradient, in: Circle())
                    .shadow(color: AvradioTheme.highlight.opacity(0.25), radius: 18, y: 10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioPlayer.isPlaying ? L10n.string("player.control.pause") : L10n.string("player.control.play"))
            .accessibilityIdentifier("player.transport.playPause")

            compactTransportButton(systemImage: "forward.fill", size: sideButtonSize, compact: compact, action: playNextStation)
                .disabled(!canCycleStations)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, compact ? 14 : 18)
        .padding(.vertical, compact ? 10 : 14)
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

    private var retrySection: some View {
        Button(L10n.string("player.retry"), action: audioPlayer.retry)
            .buttonStyle(.borderedProminent)
            .tint(AvradioTheme.highlight)
            .opacity(audioPlayer.hasFailure ? 1 : 0)
            .disabled(!audioPlayer.hasFailure)
            .accessibilityHidden(!audioPlayer.hasFailure)
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

    private func compactTransportButton(systemImage: String, size: CGFloat, compact: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: compact ? 20 : 22, weight: .bold))
                .foregroundStyle(canCycleStations ? AvradioTheme.textInverse : AvradioTheme.textInverse.opacity(0.36))
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(systemImage.contains("backward") ? "player.transport.previous" : "player.transport.next")
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: size, height: size)
        }
    }

    private func playerContentWidth(in proxy: GeometryProxy, isLandscape: Bool, horizontalInsets: EdgeInsets) -> CGFloat {
        let availableWidth = proxy.size.width - horizontalInsets.leading - horizontalInsets.trailing
        let maxWidth = isLandscape ? playerMaxLandscapeContentWidth : playerMaxContentWidth
        return min(availableWidth, maxWidth)
    }

    private func playerHorizontalInsets(in proxy: GeometryProxy, isLandscape: Bool) -> EdgeInsets {
        let horizontalPadding = isLandscape ? playerLandscapeHorizontalPadding : playerHorizontalPadding

        return EdgeInsets(
            top: 0,
            leading: horizontalPadding,
            bottom: 0,
            trailing: horizontalPadding
        )
    }

    private func playerTopInset(in proxy: GeometryProxy, isLandscape: Bool) -> CGFloat {
        if isLandscape {
            return 6
        }

        return 10
    }

    private func playerBottomInset(
        in proxy: GeometryProxy,
        isLandscape: Bool,
        horizontalInsets: EdgeInsets,
        contentWidth: CGFloat
    ) -> CGFloat {
        if isLandscape {
            return 28
        }

        return 0
    }

    private func playerContentHeight(
        in proxy: GeometryProxy,
        isLandscape: Bool,
        topInset: CGFloat,
        bottomInset: CGFloat
    ) -> CGFloat {
        let headerAllowance: CGFloat = isLandscape ? 84 : 72
        return max(proxy.size.height - topInset - bottomInset - headerAllowance, 240)
    }

    private func usesLandscapeLayout(in proxy: GeometryProxy) -> Bool {
        if let verticalSizeClass {
            return verticalSizeClass == .compact
        }

        return proxy.size.width > proxy.size.height
    }

    private func isCompactPlayer(in proxy: GeometryProxy, isLandscape: Bool) -> Bool {
        isLandscape || proxy.size.height < 780
    }

    private func portraitArtworkSize(in proxy: GeometryProxy, contentWidth: CGFloat, compact: Bool) -> CGFloat {
        return contentWidth
    }

    private func landscapeArtworkSize(in proxy: GeometryProxy, contentWidth: CGFloat) -> CGFloat {
        let maxHeight = max(proxy.size.height - playerTopInset(in: proxy, isLandscape: true) - 150, 190)
        let preferredWidth = contentWidth * 0.34
        return min(maxHeight, min(preferredWidth, 280))
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

    private func stationArtworkURL(for station: Station) -> URL? {
        guard let artwork = station.displayArtworkURL else { return nil }
        return artwork
    }

    private var canCycleStations: Bool {
        audioPlayer.canCyclePlaybackQueue
    }

    private func playNextStation() {
        guard canCycleStations else { return }
        audioPlayer.playNextInQueue()
        recordCurrentPlayback()
    }

    private func playPreviousStation() {
        guard canCycleStations else { return }
        audioPlayer.playPreviousInQueue()
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

private struct LandscapeNowPlayingRowLayout: Layout {
    let artworkSize: CGFloat
    let spacing: CGFloat
    let summaryHeight: CGFloat
    let controlsBottomNudge: CGFloat = 44

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        CGSize(width: proposal.width ?? (artworkSize + spacing), height: artworkSize)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        guard subviews.count >= 3 else { return }

        let artworkProposal = ProposedViewSize(width: artworkSize, height: artworkSize)
        let detailX = bounds.minX + artworkSize + spacing
        let detailWidth = max(bounds.width - artworkSize - spacing, 0)

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: artworkProposal
        )

        subviews[1].place(
            at: CGPoint(x: detailX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: detailWidth, height: summaryHeight)
        )

        let controlsSize = subviews[2].sizeThatFits(
            ProposedViewSize(width: detailWidth, height: nil)
        )
        let controlsY = max(bounds.minY, bounds.maxY - controlsSize.height + controlsBottomNudge)

        subviews[2].place(
            at: CGPoint(x: detailX, y: controlsY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: detailWidth, height: controlsSize.height)
        )
    }
}

#Preview {
    NowPlayingView()
        .environmentObject(AudioPlayerService())
        .environmentObject(LibraryStore(container: PersistenceController(inMemory: true).container))
}
