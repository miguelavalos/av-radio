import SwiftUI

struct FeaturedStationCard: View {
    let station: Station
    let label: String
    let subtitle: String
    let isFavorite: Bool
    let playAction: () -> Void
    let favoriteAction: () -> Void
    let detailsAction: () -> Void
    @State private var isHovered = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 520

            VStack(alignment: .leading, spacing: compact ? 16 : 18) {
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
                        StationArtworkView(station: station, size: 92)
                        featuredCopy
                    }
                } else {
                    HStack(alignment: .top, spacing: 16) {
                        StationArtworkView(station: station, size: 106)
                        featuredCopy
                    }
                }

                HStack(spacing: 10) {
                    Button(action: playAction) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Play Live")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(AvradioTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button(action: favoriteAction) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(isFavorite ? Color(red: 1, green: 0.17, blue: 0.38) : AvradioTheme.textPrimary)
                            .frame(width: 48, height: 48)
                            .background(AvradioTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(AvradioTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(compact ? 18 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(AvradioTheme.cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(isHovered ? AvradioTheme.highlight.opacity(0.18) : AvradioTheme.borderSubtle, lineWidth: 1)
                    }
            )
            .shadow(color: isHovered ? AvradioTheme.softShadow.opacity(0.24) : AvradioTheme.softShadow.opacity(0.12), radius: isHovered ? 18 : 10, y: isHovered ? 8 : 4)
            .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .scaleEffect(isHovered ? 1.008 : 1)
            .animation(.easeOut(duration: 0.16), value: isHovered)
            .onTapGesture(perform: detailsAction)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(minHeight: 220)
    }

    private var featuredCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(station.name)
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(AvradioTheme.textPrimary)
                .lineLimit(3)

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
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("LIVE NOW")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(AvradioTheme.highlight)

                Spacer()

                Text(status)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AvradioTheme.highlight)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    }
            }

            HStack(spacing: 12) {
                Group {
                    if let currentStation {
                        StationArtworkView(station: currentStation, size: 64, surfaceStyle: .dark)
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [AvradioTheme.darkSurface, AvradioTheme.highlight.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentStation?.name ?? "Ready to listen")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(AvradioTheme.textInverse)
                        .lineLimit(2)

                    Text(currentStation?.shortMeta ?? "Start playback to fill the queue.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AvradioTheme.textInverse.opacity(0.68))
                        .lineLimit(3)
                }
            }

            HStack(spacing: 8) {
                livePill(title: currentStation == nil ? "Idle" : "On Deck")

                if let currentStation {
                    livePill(title: currentStation.country, accent: currentStation.flagEmoji)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AvradioTheme.darkSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isHovered ? AvradioTheme.highlight.opacity(0.18) : AvradioTheme.borderSubtle.opacity(0.48), lineWidth: 1)
                }
        )
        .shadow(color: AvradioTheme.softShadow.opacity(isHovered ? 0.9 : 0.72), radius: isHovered ? 22 : 16, y: isHovered ? 12 : 8)
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    private func livePill(title: String, accent: String? = nil) -> some View {
        HStack(spacing: 6) {
            if let accent {
                Text(accent)
            }

            Text(title)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(AvradioTheme.textInverse.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: Capsule())
    }
}

struct StationSection<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AvradioTheme.textPrimary)
            Text(subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AvradioTheme.textSecondary)
            VStack(spacing: 12) {
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

            HStack(spacing: compact ? 12 : 14) {
                StationArtworkView(station: station, size: compact ? 56 : 62)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(station.name)
                            .font(.system(size: compact ? 16 : 17, weight: .bold))
                            .foregroundStyle(AvradioTheme.textPrimary)
                            .lineLimit(2)

                        if audioPlayer.isCurrent(station) {
                            Text(audioPlayer.isPlaying ? "LIVE" : "PAUSED")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(audioPlayer.isPlaying ? AvradioTheme.highlight : AvradioTheme.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
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
                            .font(.system(size: 11, weight: .semibold))
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
                            .frame(width: 34, height: 34)
                            .background(AvradioTheme.mutedSurface, in: Circle())
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
                            .frame(width: 40, height: 40)
                            .background(audioPlayer.isCurrent(station) ? AvradioTheme.brandGraphite : AvradioTheme.highlight, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, compact ? 14 : 16)
            .padding(.vertical, compact ? 13 : 15)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(
                        audioPlayer.isCurrent(station) ? AvradioTheme.highlight.opacity(0.22) :
                            (isHovered ? AvradioTheme.highlight.opacity(0.14) : AvradioTheme.borderSubtle),
                        lineWidth: 1
                    )
            }
            .shadow(color: AvradioTheme.softShadow.opacity(isHovered ? 0.3 : 0.22), radius: isHovered ? 14 : 10, y: isHovered ? 7 : 4)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .scaleEffect(isHovered ? 1.006 : 1)
            .animation(.easeOut(duration: 0.14), value: isHovered)
            .onTapGesture(perform: detailsAction)
            .onHover { hovering in
                isHovered = hovering
            }
        }
        .frame(minHeight: 92)
    }
}

struct EmptyStateCard: View {
    let title: String
    let detail: String
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundStyle(AvradioTheme.highlight)
            Text(title)
                .font(.headline)
                .foregroundStyle(AvradioTheme.textPrimary)
            Text(detail)
                .multilineTextAlignment(.center)
                .foregroundStyle(AvradioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(AvradioTheme.cardSurface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isHovered ? AvradioTheme.highlight.opacity(0.14) : AvradioTheme.borderSubtle, lineWidth: 1)
        }
        .shadow(color: isHovered ? AvradioTheme.softShadow.opacity(0.18) : .clear, radius: 10, y: 4)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
