import SwiftUI

enum AvradioTheme {
    static let brandBlack = Color(red: 13 / 255, green: 13 / 255, blue: 13 / 255)
    static let brandGreen = Color(red: 57 / 255, green: 181 / 255, blue: 74 / 255)
    static let brandGraphite = Color(red: 42 / 255, green: 42 / 255, blue: 42 / 255)
    static let brandWhite = Color.white

    static let neutral50 = Color(red: 247 / 255, green: 249 / 255, blue: 248 / 255)
    static let neutral100 = Color(red: 238 / 255, green: 242 / 255, blue: 239 / 255)
    static let neutral300 = Color(red: 200 / 255, green: 209 / 255, blue: 203 / 255)
    static let neutral600 = Color(red: 95 / 255, green: 104 / 255, blue: 98 / 255)
    static let neutral800 = Color(red: 26 / 255, green: 29 / 255, blue: 27 / 255)

    static let highlight = brandGreen
    static let textPrimary = brandBlack
    static let textSecondary = neutral600
    static let textInverse = brandWhite

    static let cardSurface = Color(red: 251 / 255, green: 252 / 255, blue: 251 / 255)
    static let mutedSurface = neutral100
    static let borderSubtle = neutral300
    static let borderStrong = Color(red: 149 / 255, green: 159 / 255, blue: 152 / 255)
    static let darkSurface = brandBlack
    static let darkSurfaceAlt = neutral800

    static let shellBackground = LinearGradient(
        colors: [brandWhite, neutral50, neutral100],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let onboardingBackground = LinearGradient(
        colors: [brandBlack, neutral800],
        startPoint: .top,
        endPoint: .bottom
    )

    static let signalGradient = LinearGradient(
        colors: [brandGreen.opacity(0.96), brandWhite.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let softShadow = Color.black.opacity(0.12)
}
