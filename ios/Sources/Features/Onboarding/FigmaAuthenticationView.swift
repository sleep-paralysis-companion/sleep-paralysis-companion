import SwiftUI

/// The account-entry surface is intentionally separate from the OAuth service.
/// It collects only transient UI state until a person deliberately selects a provider.
struct FigmaAuthenticationView: View {
    let state: AuthenticationPresentationState
    let feedback: String?
    let isConfigured: Bool
    let signIn: (AuthenticationProvider) -> Void

    @State private var mode: AuthenticationEntryMode = .createAccount
    @State private var fullName = ""
    @State private var localMessage: String?
    @FocusState private var fullNameIsFocused: Bool

    var body: some View {
        ZStack {
            AuthenticationSkyBackdrop(mode: mode)

            GeometryReader { proxy in
                let scale = min(
                    proxy.size.width / AuthenticationReferenceLayout.width,
                    proxy.size.height / AuthenticationReferenceLayout.height
                )
                AuthenticationReferenceLayout(
                    mode: mode,
                    fullName: $fullName,
                    fullNameIsFocused: $fullNameIsFocused,
                    message: visibleMessage,
                    isProcessing: isProcessing,
                    createAccount: createAccount,
                    choose: chooseProvider,
                    switchMode: switchMode
                )
                .frame(width: AuthenticationReferenceLayout.width, height: AuthenticationReferenceLayout.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(
                    width: AuthenticationReferenceLayout.width * scale,
                    height: AuthenticationReferenceLayout.height * scale,
                    alignment: .topLeading
                )
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }

    private var isProcessing: Bool {
        if case .processing = state {
            return true
        }
        return false
    }

    private var visibleMessage: String? {
        if let localMessage {
            return localMessage
        }
        if let feedback {
            return feedback
        }
        if state == .configurationRequired {
            return "Provider sign-in will be available once configuration is complete."
        }
        if state == .sessionExpired {
            return "Your session ended. Choose a provider to continue."
        }
        return nil
    }

    private func createAccount() {
        let name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            localMessage = "Enter your name to continue."
            fullNameIsFocused = true
            return
        }
        fullNameIsFocused = false
        localMessage = "Choose Google or Apple to create your account."
    }

    private func chooseProvider(_ provider: AuthenticationProvider) {
        fullNameIsFocused = false
        guard isConfigured else {
            localMessage = "Provider sign-in will be available once configuration is complete."
            return
        }
        localMessage = nil
        signIn(provider)
    }

    private func switchMode() {
        mode = mode == .createAccount ? .logIn : .createAccount
        fullNameIsFocused = false
        localMessage = nil
    }
}

private enum AuthenticationEntryMode: Equatable {
    case createAccount
    case logIn
}

private struct AuthenticationReferenceLayout: View {
    static let width: CGFloat = 430
    static let height: CGFloat = 932

    let mode: AuthenticationEntryMode
    @Binding var fullName: String
    var fullNameIsFocused: FocusState<Bool>.Binding
    let message: String?
    let isProcessing: Bool
    let createAccount: () -> Void
    let choose: (AuthenticationProvider) -> Void
    let switchMode: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            AuthenticationMoon()
                .position(x: 102, y: 151)

            if mode == .createAccount {
                createAccountLayout
            } else {
                loginLayout
            }
        }
        .foregroundStyle(.white)
    }

    private var createAccountLayout: some View {
        ZStack(alignment: .topLeading) {
            heading(
                "Create your account",
                subtitle: "Start sleeping better tonight",
                verticalPosition: 249
            )

            TextField("Full Name", text: $fullName)
                .font(AppFont.inter(size: 17, relativeTo: .body))
                .foregroundStyle(.white)
                .tint(AuthenticationPalette.actionEnd)
                .focused(fullNameIsFocused)
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .onSubmit(createAccount)
                .padding(.horizontal, 42)
                .frame(width: 370, height: 72)
                .background(AuthenticationPalette.controlFill)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AuthenticationPalette.controlStroke, lineWidth: 1)
                }
                .position(x: 215, y: 376)
                .accessibilityIdentifier("authentication.fullName")

            HStack(spacing: 18) {
                AuthenticationProviderButton(
                    provider: .google,
                    isProcessing: isProcessing,
                    action: { choose(.google) }
                )
                AuthenticationProviderButton(
                    provider: .apple,
                    isProcessing: isProcessing,
                    action: { choose(.apple) }
                )
            }
            .position(x: 215, y: 469)

            if let message {
                AuthenticationInlineMessage(message: message)
                    .position(x: 215, y: 548)
            }

            Button(action: createAccount) {
                Text("Create account")
                    .font(AppFont.inter(size: 17, relativeTo: .headline, weight: .semibold))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [AuthenticationPalette.actionStart, AuthenticationPalette.actionEnd],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .frame(width: 350, height: 62)
            .position(x: 215, y: 731)
            .accessibilityIdentifier("authentication.createAccount")

            policyLine
                .position(x: 215, y: 789)

            Button(action: switchMode) {
                HStack(spacing: 4) {
                    Text("Already have an account ?")
                        .foregroundStyle(AuthenticationPalette.secondaryText)
                    Text("Log in")
                        .foregroundStyle(AuthenticationPalette.link)
                }
                .font(AppFont.inter(size: 15, relativeTo: .subheadline))
            }
            .buttonStyle(.plain)
            .position(x: 215, y: 834)
            .accessibilityIdentifier("authentication.goToLogin")
        }
    }

    private var loginLayout: some View {
        ZStack(alignment: .topLeading) {
            heading("Welcome Back", subtitle: "Continue your journey", verticalPosition: 282)

            VStack(spacing: 24) {
                AuthenticationProviderButton(
                    provider: .google,
                    isProcessing: isProcessing,
                    action: { choose(.google) },
                    expanded: true
                )
                AuthenticationProviderButton(
                    provider: .apple,
                    isProcessing: isProcessing,
                    action: { choose(.apple) },
                    expanded: true
                )
            }
            .position(x: 215, y: 542)

            if let message {
                AuthenticationInlineMessage(message: message)
                    .position(x: 215, y: 627)
            }

            VStack(spacing: 25) {
                Text("Don't have an account ?")
                    .font(AppFont.inter(size: 16, relativeTo: .body, weight: .semibold))
                    .foregroundStyle(AuthenticationPalette.secondaryText)
                Button("Sign up", action: switchMode)
                    .font(AppFont.inter(size: 16, relativeTo: .body))
                    .foregroundStyle(AuthenticationPalette.link)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("authentication.goToCreateAccount")
            }
            .frame(width: 300)
            .position(x: 215, y: 702)

            if isProcessing {
                ProgressView()
                    .tint(.white)
                    .position(x: 215, y: 766)
                    .accessibilityLabel("Opening provider")
            }
        }
    }

    private func heading(_ title: String, subtitle: String, verticalPosition: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(AppFont.latoBold(size: 29, relativeTo: .title))
                .tracking(-0.55)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .font(AppFont.inter(size: 17, relativeTo: .headline, weight: .semibold))
                .foregroundStyle(AuthenticationPalette.secondaryText)
        }
        .frame(width: 348, alignment: .leading)
        .position(x: 215, y: verticalPosition + 31)
    }

    private var policyLine: some View {
        HStack(spacing: 4) {
            Text("By signing up you agree to our")
                .foregroundStyle(AuthenticationPalette.secondaryText)
            Link("Terms", destination: LegalSupport.termsURL)
                .foregroundStyle(AuthenticationPalette.link)
                .accessibilityIdentifier("authentication.terms")
            Text("and")
                .foregroundStyle(AuthenticationPalette.secondaryText)
            Link("Privacy Policy", destination: LegalSupport.privacyURL)
                .foregroundStyle(AuthenticationPalette.link)
                .accessibilityIdentifier("authentication.privacy")
        }
        .font(AppFont.inter(size: 13, relativeTo: .footnote))
        .buttonStyle(.plain)
        .frame(width: 350)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
    }
}

private struct AuthenticationProviderButton: View {
    let provider: AuthenticationProvider
    let isProcessing: Bool
    let action: () -> Void
    var expanded = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                providerMark
                    .frame(width: 26, height: 26)
                Text(provider == .google ? "Google" : "Apple")
                    .font(AppFont.inter(size: 17, relativeTo: .headline, weight: .semibold))
            }
            .foregroundStyle(AuthenticationPalette.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(AuthenticationPalette.controlFill)
        .clipShape(RoundedRectangle(cornerRadius: expanded ? 27 : 21))
        .overlay {
            RoundedRectangle(cornerRadius: expanded ? 27 : 21)
                .stroke(AuthenticationPalette.controlStroke, lineWidth: 1)
        }
        .frame(width: expanded ? 338 : 159, height: expanded ? 56 : 50)
        .opacity(isProcessing ? 0.72 : 1)
        .disabled(isProcessing)
        .accessibilityIdentifier("authentication.\(provider.rawValue)")
        .accessibilityLabel("Continue with \(provider == .google ? "Google" : "Apple")")
    }

    @ViewBuilder
    private var providerMark: some View {
        switch provider {
        case .google:
            Image(decorative: "GoogleGLogo", bundle: .main)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                // Google's supplied artwork is kept at its native aspect ratio.
                .frame(width: 18, height: 18)
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(AuthenticationPalette.appleMark)
        }
    }
}

private struct AuthenticationInlineMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(AppFont.inter(size: 12, relativeTo: .caption))
            .foregroundStyle(AuthenticationPalette.secondaryText)
            .multilineTextAlignment(.center)
            .frame(width: 340)
            .accessibilityIdentifier("authentication.message")
    }
}

private struct AuthenticationMoon: View {
    var body: some View {
        MoonMark(size: 126)
    }
}

private struct AuthenticationSkyBackdrop: View {
    let mode: AuthenticationEntryMode

    // Decorative star data is most readable as fixed x/y/size/color tuples.
    // swiftlint:disable:next large_tuple
    private let stars: [(CGFloat, CGFloat, CGFloat, Color)] = [
        (42, 15, 2.0, AuthenticationPalette.starPurple), (151, 20, 2.6, .white.opacity(0.34)),
        (227, 0, 2.1, AuthenticationPalette.starPurple), (406, 19, 2.2, AuthenticationPalette.starPurple),
        (90, 64, 2.0, AuthenticationPalette.starPurple), (319, 75, 1.5, AuthenticationPalette.starBlue),
        (33, 225, 1.6, AuthenticationPalette.starBlue), (86, 154, 2.2, AuthenticationPalette.starPurple),
        (247, 190, 2.8, .white.opacity(0.32)), (321, 154, 1.2, AuthenticationPalette.starPurple),
        (391, 123, 1.5, AuthenticationPalette.starBlue), (44, 360, 2.4, .white.opacity(0.34)),
        (87, 412, 2.5, .white.opacity(0.31)), (122, 260, 2.5, .white.opacity(0.35)),
        (216, 248, 2.5, .white.opacity(0.35)), (302, 271, 1.6, AuthenticationPalette.starBlue),
        (377, 468, 1.7, AuthenticationPalette.starPurple), (117, 520, 2.6, .white.opacity(0.33)),
        (180, 627, 2.5, .white.opacity(0.32)), (332, 669, 1.1, AuthenticationPalette.starBlue),
        (128, 696, 2.0, AuthenticationPalette.starPurple), (391, 756, 1.1, AuthenticationPalette.starBlue),
        (34, 879, 1.1, AuthenticationPalette.starBlue), (188, 876, 2.7, .white.opacity(0.32)),
        (378, 897, 1.1, AuthenticationPalette.starBlue),
    ]

    var body: some View {
        GeometryReader { proxy in
            let xScale = proxy.size.width / AuthenticationReferenceLayout.width
            let yScale = proxy.size.height / AuthenticationReferenceLayout.height
            ZStack {
                LinearGradient(
                    colors: [AuthenticationPalette.background, Color(red: 0.016, green: 0.008, blue: 0.11)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                    Circle()
                        .fill(star.3)
                        .frame(width: star.2 * 2, height: star.2 * 2)
                        .position(x: star.0 * xScale, y: star.1 * yScale)
                }
                AuthenticationConstellation(mode: mode)
                    .stroke(AuthenticationPalette.constellation, lineWidth: 1)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct AuthenticationConstellation: Shape {
    let mode: AuthenticationEntryMode

    func path(in rect: CGRect) -> Path {
        let xScale = rect.width / 430
        let yScale = rect.height / 932
        var path = Path()
        switch mode {
        case .createAccount:
            path.move(to: CGPoint(x: 50 * xScale, y: 281 * yScale))
            path.addLine(to: CGPoint(x: 228 * xScale, y: 249 * yScale))
            path.move(to: CGPoint(x: 392 * xScale, y: 225 * yScale))
            path.addLine(to: CGPoint(x: 391 * xScale, y: 310 * yScale))
            path.addLine(to: CGPoint(x: 303 * xScale, y: 351 * yScale))
        case .logIn:
            path.move(to: CGPoint(x: 81 * xScale, y: 284 * yScale))
            path.addLine(to: CGPoint(x: 235 * xScale, y: 256 * yScale))
            path.move(to: CGPoint(x: 392 * xScale, y: 226 * yScale))
            path.addLine(to: CGPoint(x: 390 * xScale, y: 311 * yScale))
            path.addLine(to: CGPoint(x: 310 * xScale, y: 353 * yScale))
            path.addLine(to: CGPoint(x: 323 * xScale, y: 416 * yScale))
        }
        return path
    }
}

private enum AuthenticationPalette {
    static let background = Color(red: 0.015, green: 0.005, blue: 0.10)
    static let controlFill = Color(red: 0.09, green: 0.06, blue: 0.22).opacity(0.92)
    static let controlStroke = Color(red: 0.31, green: 0.21, blue: 0.55)
    static let actionStart = Color(red: 0.36, green: 0.25, blue: 0.78)
    static let actionEnd = Color(red: 0.22, green: 0.49, blue: 0.84)
    static let secondaryText = Color(red: 0.58, green: 0.55, blue: 0.72)
    static let link = Color(red: 0.58, green: 0.50, blue: 0.97)
    static let appleMark = Color(red: 0.70, green: 0.69, blue: 0.79)
    static let constellation = Color(red: 0.07, green: 0.22, blue: 0.45).opacity(0.78)
    static let starPurple = Color(red: 0.58, green: 0.45, blue: 0.96).opacity(0.78)
    static let starBlue = Color(red: 0.20, green: 0.46, blue: 0.70).opacity(0.72)
}
