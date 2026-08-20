import SwiftUI

enum AppColorRole {
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let accent = Color(uiColor: .systemIndigo)
    static let success = Color(uiColor: .systemGreen)
    static let caution = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)

    static func separator(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.primary : Color(uiColor: .separator)
    }
}

enum AppTypographyRole {
    static let hero = AppFont.latoBold(size: 40, relativeTo: .largeTitle)
    static let screenTitle = AppFont.latoBold(size: 28, relativeTo: .title)
    static let sectionTitle = AppFont.latoBold(size: 24, relativeTo: .title2)
    static let cardTitle = AppFont.latoSemiBold(size: 20, relativeTo: .title3)
    static let subsectionTitle = AppFont.latoSemiBold(size: 18, relativeTo: .headline)
    static let body = AppFont.inter(size: 16, relativeTo: .body)
    static let supporting = AppFont.inter(size: 16, relativeTo: .callout)
    static let control = AppFont.interSemiBold(size: 16, relativeTo: .headline)
    static let label = AppFont.interMedium(size: 12, relativeTo: .caption)
    static let footnote = AppFont.inter(size: 13, relativeTo: .footnote)
    static let caption = AppFont.inter(size: 11, relativeTo: .caption)
}

enum AppFont {
    private static let interFamily = "Inter"
    private static let latoBoldFamily = "Lato-Bold"
    private static let latoRegularFamily = "Lato-Regular"
    private static let latoSemiBoldFamily = "Lato-SemiBold"

    static func inter(
        size: CGFloat,
        relativeTo style: Font.TextStyle,
        weight: Font.Weight = .regular
    ) -> Font {
        Font.custom(interFamily, size: size, relativeTo: style).weight(weight)
    }

    static func interMedium(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        inter(size: size, relativeTo: style, weight: .medium)
    }

    static func interSemiBold(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        inter(size: size, relativeTo: style, weight: .semibold)
    }

    static func latoBold(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(latoBoldFamily, size: size, relativeTo: style)
    }

    static func latoRegular(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(latoRegularFamily, size: size, relativeTo: style)
    }

    static func latoSemiBold(size: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(latoSemiBoldFamily, size: size, relativeTo: style)
    }
}

nonisolated enum AppSpacing {
    static let tight: CGFloat = 4
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let spacious: CGFloat = 24
    static let section: CGFloat = 32
    static let screen: CGFloat = 24
    static let minimumControl: CGFloat = 48
}

nonisolated enum AppShape {
    static let controlRadius: CGFloat = 14
    static let cardRadius: CGFloat = 20
}

nonisolated enum AppMotion {
    static func standardDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : 0.22
    }
}

nonisolated enum AppAccessibility {
    static func verticalSpacing(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? AppSpacing.spacious : AppSpacing.standard
    }

    static func contentPadding(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? AppSpacing.standard : AppSpacing.screen
    }
}
