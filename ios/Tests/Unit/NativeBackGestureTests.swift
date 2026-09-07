import Foundation
@testable import SleepParalysisCompanion
import UIKit
import XCTest

final class NativeBackGestureTests: XCTestCase {
    @MainActor
    func testRootControllerFreezePreventionReturnsFalseWhenCountIsOne() {
        let navController = UINavigationController(rootViewController: UIViewController())
        let coordinator = NativeBackGestureEnabler.Coordinator()
        coordinator.attach(to: navController)

        XCTAssertEqual(navController.viewControllers.count, 1)

        let panGesture = UIPanGestureRecognizer()
        let shouldBegin = coordinator.gestureRecognizerShouldBegin(panGesture)

        // Must return false to prevent UIKit from attempting pop at root and freezing the app
        XCTAssertFalse(shouldBegin, "interactivePopGestureRecognizer must not begin when at root view controller")
    }

    @MainActor
    func testGestureBeginsWhenMultipleViewControllersArePresentAndNotTransitioning() {
        let navController = UINavigationController(rootViewController: UIViewController())
        let pushedVC = UIViewController()
        navController.setViewControllers([navController.viewControllers[0], pushedVC], animated: false)

        let coordinator = NativeBackGestureEnabler.Coordinator()
        coordinator.attach(to: navController)

        XCTAssertEqual(navController.viewControllers.count, 2)
        XCTAssertFalse(coordinator.isTransitioning)

        let panGesture = UIPanGestureRecognizer()
        let shouldBegin = coordinator.gestureRecognizerShouldBegin(panGesture)

        XCTAssertTrue(shouldBegin, "interactivePopGestureRecognizer must begin when more than 1 view controller exists")
    }

    @MainActor
    func testGesturePriorityRequiresChildGesturesToFail() {
        let coordinator = NativeBackGestureEnabler.Coordinator()
        let popGesture = UIPanGestureRecognizer()
        let childScrollGesture = UIPanGestureRecognizer()

        let shouldBeRequiredToFail = coordinator.gestureRecognizer(
            popGesture,
            shouldBeRequiredToFailBy: childScrollGesture
        )

        XCTAssertTrue(
            shouldBeRequiredToFail,
            "Edge back gesture must be given priority over child horizontal scroll views or sliders"
        )
    }

    @MainActor
    func testGestureDoesNotRecognizeSimultaneouslyWithOtherGestures() {
        let coordinator = NativeBackGestureEnabler.Coordinator()
        let popGesture = UIPanGestureRecognizer()
        let otherGesture = UIPanGestureRecognizer()

        let simultaneous = coordinator.gestureRecognizer(
            popGesture,
            shouldRecognizeSimultaneouslyWith: otherGesture
        )

        XCTAssertFalse(
            simultaneous,
            "Edge back gesture should not simultaneously activate other gesture recognizers"
        )
    }

    @MainActor
    func testAppModelPathUpdatesSynchronizeWithInteractivePop() {
        let model = makeTestAppModel()
        model.setLaunchDestinationForTesting(.home)
        model.selectTab(.me)

        XCTAssertEqual(model.path, [])

        // Pushing screens
        model.open(.account)
        XCTAssertEqual(model.path, [.account])

        model.open(.helpLegal)
        XCTAssertEqual(model.path, [.account, .helpLegal])

        // Simulating the NavigationStack interactive pop callback (which invokes model.setPath($0))
        model.setPath(Array(model.path.dropLast()))
        XCTAssertEqual(model.path, [.account])

        model.setPath(Array(model.path.dropLast()))
        XCTAssertEqual(model.path, [])
    }
}
