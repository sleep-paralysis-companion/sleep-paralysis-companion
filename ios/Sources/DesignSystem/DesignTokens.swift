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
    static let hero = Font.largeTitle.weight(.bold)
    static let screenTitle = Font.title.weight(.bold)
    static let sectionTitle = Font.title2.weight(.semibold)
    static let cardTitle = Font.title3.weight(.semibold)
    static let body = Font.body
    static let supporting = Font.callout
    static let control = Font.headline
    static let label = Font.caption.weight(.semibold)
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
