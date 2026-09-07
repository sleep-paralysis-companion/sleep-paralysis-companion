import SwiftUI
import UIKit

/// Enables the native iOS edge swipe-to-back gesture (`interactivePopGestureRecognizer`)
/// across all screens pushed within a `NavigationStack`, even when the navigation bar
/// or back button is hidden.
@MainActor
public struct NativeBackGestureEnabler: UIViewControllerRepresentable {
    public init() {}

    public func makeUIViewController(context: Context) -> NativeBackGestureController {
        NativeBackGestureController(coordinator: context.coordinator)
    }

    public func updateUIViewController(_ uiViewController: NativeBackGestureController, context: Context) {
        uiViewController.configureNavigationController()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    public final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var navigationController: UINavigationController?

        var isTransitioning: Bool {
            guard let navigationController else { return false }
            return navigationController.transitionCoordinator != nil
                || navigationController.topViewController?.transitionCoordinator != nil
        }

        func attach(to navigationController: UINavigationController) {
            self.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.isEnabled = true
            navigationController.interactivePopGestureRecognizer?.delegate = self
        }

        public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let navigationController else { return false }

            // 1. Root Controller Freeze Prevention:
            // Strictly verify viewControllers.count > 1.
            // If count <= 1, returning true causes UIKit to enter a broken pop state and freeze the app.
            guard navigationController.viewControllers.count > 1 else {
                return false
            }

            // 2. In-Flight Transition Guard:
            // Prevent triggering an interactive pop while a transition animation is already in progress.
            guard !isTransitioning else {
                return false
            }

            return true
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            // 3. Gesture Priority:
            // Ensure edge swipes are not swallowed by child horizontal ScrollViews, carousels, or sliders.
            true
        }

        public func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            false
        }
    }
}

@MainActor
public final class NativeBackGestureController: UIViewController {
    private let coordinator: NativeBackGestureEnabler.Coordinator

    init(coordinator: NativeBackGestureEnabler.Coordinator) {
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        configureNavigationController()
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationController()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configureNavigationController()
    }

    func configureNavigationController() {
        guard let navigationController = findNavigationController() else { return }
        coordinator.attach(to: navigationController)
    }

    private func findNavigationController() -> UINavigationController? {
        if let nav = navigationController {
            return nav
        }
        var current: UIViewController? = parent
        while let parentVC = current {
            if let nav = parentVC as? UINavigationController ?? parentVC.navigationController {
                return nav
            }
            current = parentVC.parent
        }
        return nil
    }
}

public struct NativeBackGestureModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background(NativeBackGestureEnabler())
    }
}

public extension View {
    func enableNativeBackGesture() -> some View {
        modifier(NativeBackGestureModifier())
    }
}
