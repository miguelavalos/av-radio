import SwiftUI

struct FeaturedStationCard: View {
    let station: Station
    let label: String
    let subtitle: String
    let isFavorite: Bool
    let playAction: () -> Void
    let favoriteAction: () -> Void
    let detailsAction: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 520

            VStack(alignment: .leading, spacing: compact ? 12 : 14) {
                HStack(alignment: .top) {
                    Text(label)
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AvradioTheme.highlight)

                    Spacer()

                    Text(station.country)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AvradioTheme.textSecondary)
                }

                if compact {
                    VStack(alignment: .leading, spacing: 14) {
                        StationArtworkView(station: station, size: 76)
                        featuredCopy
                    }
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        StationArtworkView(station: station, size: 86)
                        featuredCopy
                    }
                }

                HStack(spacing: 8) {
                    Button(action: playAction) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Play")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: favoriteAction) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(compact ? 14 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(AvradioTheme.cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                    }
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .onTapGesture(perform: detailsAction)
        }
        .frame(minHeight: 168)
    }

    private var featuredCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.name)
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)
                .lineLimit(2)

            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !station.tagsList.isEmpty {
                Text(station.tagsList.prefix(3).joined(separator: " · "))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct LiveNowPanel: View {
    let currentStation: Station?
    let status: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Now Playing")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)

                Spacer()

                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AvradioTheme.highlight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AvradioTheme.highlight.opacity(0.1), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(AvradioTheme.highlight.opacity(0.18), lineWidth: 1)
                    }
            }

            HStack(spacing: 12) {
                Group {
                    if let currentStation {
                        StationArtworkView(station: currentStation, size: 52)
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(AvradioTheme.mutedSurface)
                            .frame(width: 52, height: 52)
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(currentStation?.name ?? "Ready to listen")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AvradioTheme.textPrimary)
                        .lineLimit(2)

                    Text(currentStation?.shortMeta ?? "Start playback to fill the queue.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                livePill(title: currentStation == nil ? "Idle" : "On Deck")

                if let currentStation {
                    livePill(title: currentStation.country, accent: currentStation.flagEmoji)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(AvradioTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func livePill(title: String, accent: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let accent {
                Text(accent)
            }

            Text(title)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AvradioTheme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(AvradioTheme.mutedSurface, in: Capsule())
    }
}

struct StationSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AvradioTheme.textPrimary)
                Spacer()
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AvradioTheme.textSecondary)
                    .lineLimit(1)
            }
            VStack(spacing: 8) {
                content
            }
        }
    }
}

struct StationRowCard: View {
    @EnvironmentObject private var audioPlayer: AudioPlayerService

    let station: Station
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    let playAction: () -> Void
    let detailsAction: () -> Void
    @State private var isHovered = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 540

            HStack(spacing: compact ? 10 : 12) {
                StationArtworkView(station: station, size: compact ? 46 : 50)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(station.name)
                            .font(.system(size: compact ? 14 : 15, weight: .semibold))
                            .foregroundStyle(AvradioTheme.textPrimary)
                            .lineLimit(2)

                        if audioPlayer.isCurrent(station) {
                            Text(audioPlayer.isPlaying ? "LIVE" : "PAUSED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(audioPlayer.isPlaying ? AvradioTheme.highlight : AvradioTheme.textSecondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(audioPlayer.isPlaying ? AvradioTheme.highlight.opacity(0.12) : AvradioTheme.mutedSurface)
                                )
                        }
                    }

                    Text(station.detailLine.isEmpty ? station.shortMeta : station.detailLine)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AvradioTheme.textSecondary.opacity(0.88))
                        .lineLimit(1)

                    if !compact, !station.tagsList.isEmpty {
                        Text(station.tagsList.prefix(3).joined(separator: " · "))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AvradioTheme.highlight)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    Button(action: toggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(AvradioTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        if audioPlayer.isCurrent(station) {
                            audioPlayer.togglePlayback()
                        } else {
                            playAction()
                        }
                    } label: {
                        Image(systemName: audioPlayer.isCurrent(station) && audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(audioPlayer.isCurrent(station) ? AvradioTheme.brandGraphite : AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, compact ? 10 : 12)
            .padding(.vertical, compact ? 9 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(
                        audioPlayer.isCurrent(station) ? AvradioTheme.highlight.opacity(0.22) :
                            (isHovered ? AvradioTheme.highlight.opacity(0.14) : AvradioTheme.borderSubtle),
                        lineWidth: 1
                    )
            }
            .shadow(color: AvradioTheme.softShadow.opacity(isHovered ? 0.12 : 0), radius: 8, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .onTapGesture(perform: detailsAction)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(minHeight: 72)
    }
}

struct EmptyStateCard: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 22))
                .foregroundStyle(AvradioTheme.highlight)
            Text(title)
                .font(.headline)
                .foregroundStyle(AvradioTheme.textPrimary)
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(AvradioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
        }
    }
}
