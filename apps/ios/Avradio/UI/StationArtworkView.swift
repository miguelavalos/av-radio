import SwiftUI

struct StationArtworkView: View {
    let station: Station
    let size: CGFloat
    var contentInsetRatio: CGFloat = 0.16
    var cornerRadiusRatio: CGFloat = 0.24

    var body: some View {
        artworkContent
            .frame(width: size, height: size)
            .background(artworkBackground)
            .clipShape(artworkShape)
            .overlay {
                artworkShape
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }

    private var artworkContent: some View {
        Group {
            if let artworkURL = station.displayArtworkURL {
                AsyncImage(url: artworkURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: size, height: size)
                            .clipped()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
    }

    private var fallback: some View {
        ZStack {
            Circle()
                .fill(AvradioTheme.highlight.opacity(0.18))
                .frame(width: size * 0.62, height: size * 0.62)

            VStack(spacing: size * 0.08) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: size * 0.22, weight: .semibold))
                    .foregroundStyle(AvradioTheme.highlight)

                Text(station.initials)
                    .font(.system(size: size * 0.16, weight: .bold))
                    .foregroundStyle(AvradioTheme.textInverse.opacity(0.9))
            }
        }
    }

    private var artworkBackground: some View {
        AvradioTheme.darkSurface
    }

    private var artworkShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * cornerRadiusRatio, style: .continuous)
    }
}
