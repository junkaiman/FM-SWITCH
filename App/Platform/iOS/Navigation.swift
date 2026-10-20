import SwiftUI
import UIKit

extension View {
    /// Hides the navigation bar, as each screen draws its own header and BACK button, keeping the
    /// swipe from the left edge that goes back.
    func hidesNavigationBar() -> some View {
        toolbar(.hidden, for: .navigationBar)
            .background(SwipeBack.Installer().frame(width: 0, height: 0))
    }
}

/// Puts back the swipe from the left edge that goes back, which UIKit turns off while the
/// navigation bar is hidden.
@MainActor
private final class SwipeBack: NSObject, UIGestureRecognizerDelegate {
    static let shared = SwipeBack()
    private weak var navigationController: UINavigationController?

    /// Only with a page to go back to: swiping on the first page would leave the stack stuck.
    func gestureRecognizerShouldBegin(_: UIGestureRecognizer) -> Bool {
        (navigationController?.viewControllers.count ?? 0) > 1
    }

    /// Finds the navigation controller each time a page appears and hands its swipe to ``shared``.
    struct Installer: UIViewControllerRepresentable {
        func makeUIViewController(context _: Context) -> Controller { Controller() }
        func updateUIViewController(_: Controller, context _: Context) {}
    }

    final class Controller: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let navigationController else { return }
            SwipeBack.shared.navigationController = navigationController
            navigationController.interactivePopGestureRecognizer?.delegate = SwipeBack.shared
        }
    }
}
