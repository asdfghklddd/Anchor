// Role: bridges UIKit's `presentationControllerDidAttemptToDismiss`, so a swipe on a dirty sheet can ask first.

#if os(iOS)
import SwiftUI
import UIKit

/// Tells a sheet whose swipe-down is held back (`interactiveDismissDisabled`)
/// that the person tried, so it can ask before throwing input away, as
/// Reminders and Mail do. SwiftUI keeps its own presentation delegate; this
/// one stands in front of it and passes everything else through.
struct SheetDismissAttempt: UIViewControllerRepresentable {
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.onAttempt = onAttempt
        controller.install()
    }

    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        var onAttempt: () -> Void = {}
        private weak var original: UIAdaptivePresentationControllerDelegate?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        /// The sheet is the topmost parent; its presentation controller is the one to watch.
        func install() {
            var sheet: UIViewController = self
            while let parent = sheet.parent { sheet = parent }
            guard let presentation = sheet.presentationController, presentation.delegate !== self else { return }
            original = presentation.delegate
            presentation.delegate = self
        }

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            original?.presentationControllerDidAttemptToDismiss?(presentationController)
            onAttempt()
        }

        override func responds(to selector: Selector!) -> Bool {
            super.responds(to: selector) || (original?.responds(to: selector) ?? false)
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if original?.responds(to: selector) == true, !super.responds(to: selector) { return original }
            return super.forwardingTarget(for: selector)
        }
    }
}
#endif
