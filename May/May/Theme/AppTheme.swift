import SwiftUI

enum AppTheme {
    static let background = Color(red: 0.956, green: 0.972, blue: 0.972)
    static let surface = Color.white
    static let softSurface = Color(red: 0.945, green: 0.953, blue: 0.965)
    static let primaryText = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let secondaryText = Color(red: 0.541, green: 0.573, blue: 0.616)
    static let mutedText = Color(red: 0.639, green: 0.670, blue: 0.714)
    static let primaryButton = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let success = Color(red: 0.388, green: 0.780, blue: 0.314)
    static let warning = Color(red: 0.922, green: 0.592, blue: 0.200)
    static let error = Color(red: 0.878, green: 0.235, blue: 0.235)
    static let border = Color(red: 0.894, green: 0.910, blue: 0.933)

    static let cardRadius: CGFloat = 20
    static let controlRadius: CGFloat = 12
    static let screenPadding: CGFloat = 20

    static func responsiveContentWidth(
        for screenWidth: CGFloat,
        compactWidth: CGFloat = 328,
        expandedWidth: CGFloat = 360,
        sideMargin: CGFloat = 56
    ) -> CGFloat {
        min(max(screenWidth - sideMargin, compactWidth), expandedWidth)
    }

    static var cardShadow: some ViewModifier {
        ShadowModifier(color: Color.black.opacity(0.07), radius: 24, x: 0, y: 14)
    }
}

private struct ShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: radius, x: x, y: y)
    }
}

extension Font {
    static let appLargeTitle = Font.system(size: 28, weight: .bold, design: .default)
    static let appTitle = Font.system(size: 22, weight: .bold, design: .default)
    static let appHeadline = Font.system(size: 16, weight: .bold, design: .default)
    static let appSubheadline = Font.system(size: 13, weight: .semibold, design: .default)
    static let appBody = Font.system(size: 13, weight: .regular, design: .default)
    static let appCaption = Font.system(size: 12, weight: .regular, design: .default)
}
