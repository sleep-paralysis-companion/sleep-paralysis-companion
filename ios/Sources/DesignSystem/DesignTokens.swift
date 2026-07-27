import SwiftUI

enum AppColorRole {
    static let background = Color(uiColor: .systemBackground)
    static let surface = Color(uiColor: .secondarySystemBackground)
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary

    static func separator(_ contrast: ColorSchemeContrast) -> Color {
        contrast == .increased ? Color.primary : Color(uiColor: .separator)
    }

    static let accent = Color.accentColor
}

enum AppTypographyRole {
    static let screenTitle = Font.largeTitle.bold()
    static let sectionTitle = Font.title2.weight(.semibold)
    static let body = Font.body
    static let supporting = Font.callout
    static let control = Font.headline
}

enum AppSpacing {
    static let compact: CGFloat = 8
    static let standard: CGFloat = 16
    static let spacious: CGFloat = 24
    static let screen: CGFloat = 24
    static let minimumControl: CGFloat = 44
}

enum AppShape {
    static let controlRadius: CGFloat = 14
    static let cardRadius: CGFloat = 20
}

enum AppMotion {
    static func standardDuration(reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : 0.22
    }
}

enum AppAccessibility {
    static func verticalSpacing(for size: DynamicTypeSize) -> CGFloat {
        size.isAccessibilitySize ? AppSpacing.spacious : AppSpacing.standard
    }
}
