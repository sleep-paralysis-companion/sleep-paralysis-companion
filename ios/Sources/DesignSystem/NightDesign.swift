import SwiftUI

struct NightBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.018, blue: 0.12),
                        Color(red: 0.055, green: 0.02, blue: 0.20),
                        Color(red: 0.02, green: 0.015, blue: 0.10),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color.purple.opacity(0.42), .clear],
                    center: .topTrailing,
                    startRadius: 8,
                    endRadius: proxy.size.width * 0.7
                )
                ForEach(0 ..< 28, id: \.self) { index in
                    Circle()
                        .fill(index.isMultiple(of: 5) ? Color.cyan.opacity(0.7) : Color.white.opacity(0.55))
                        .frame(width: index.isMultiple(of: 7) ? 3 : 1.5)
                        .position(
                            x: pseudoPosition(index, modulus: 97) * proxy.size.width,
                            y: pseudoPosition(index + 31, modulus: 89) * proxy.size.height
                        )
                        .accessibilityHidden(true)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func pseudoPosition(_ seed: Int, modulus: Int) -> CGFloat {
        CGFloat((seed * 37 + 19) % modulus) / CGFloat(modulus)
    }
}

struct NightScreen<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            NightBackground()
            ScrollView {
                content
                    .padding(AppAccessibility.contentPadding(for: dynamicTypeSize))
                    .frame(maxWidth: 680, alignment: .leading)
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
    }
}

struct MoonMark: View {
    var size: CGFloat = 112

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.purple.opacity(0.75), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
            Circle()
                .fill(Color(red: 0.03, green: 0.02, blue: 0.14))
                .frame(width: size, height: size)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.indigo.opacity(0.45))
                        .frame(width: size * 0.44)
                }
        }
        .accessibilityHidden(true)
    }
}

struct NightCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.075))
            .clipShape(RoundedRectangle(cornerRadius: AppShape.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppShape.cardRadius)
                    .stroke(Color.indigo.opacity(0.35))
            }
    }
}
