import MessageUI
import UIKit

/// Presents **`MFMessageComposeViewController`** from the frontmost UIKit host — not a SwiftUI sheet (avoids a blank sheet flash before Messages).
enum FriendInviteSMSComposePresentation {
    private static var activeCoordinator: Coordinator?

    @MainActor
    static func present(recipients: [String], body: String) {
        guard MFMessageComposeViewController.canSendText() else {
            openSMSFallbackURL(recipients: recipients, body: body)
            return
        }
        guard let presenter = frontmostViewController() else {
            openSMSFallbackURL(recipients: recipients, body: body)
            return
        }

        let composer = MFMessageComposeViewController()
        composer.recipients = recipients
        composer.body = body
        let coordinator = Coordinator {
            activeCoordinator = nil
        }
        activeCoordinator = coordinator
        composer.messageComposeDelegate = coordinator
        presenter.present(composer, animated: true)
    }

    @MainActor
    static func openSMSFallbackURL(recipients: [String], body: String) {
        var components = URLComponents()
        components.scheme = "sms"
        if let first = recipients.first, !first.isEmpty {
            components.path = first
        }
        components.queryItems = [URLQueryItem(name: "body", value: body)]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private static func frontmostViewController() -> UIViewController? {
        guard let root = keyWindow?.rootViewController else { return nil }
        return walkPresented(from: root)
    }

    @MainActor
    private static func walkPresented(from base: UIViewController) -> UIViewController {
        if let navigation = base as? UINavigationController,
           let visible = navigation.visibleViewController {
            return walkPresented(from: visible)
        }
        if let tab = base as? UITabBarController,
           let selected = tab.selectedViewController {
            return walkPresented(from: selected)
        }
        if let presented = base.presentedViewController {
            return walkPresented(from: presented)
        }
        return base
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        private let onReleased: () -> Void

        init(onReleased: @escaping () -> Void) {
            self.onReleased = onReleased
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            controller.dismiss(animated: true) { [onReleased] in
                onReleased()
            }
        }
    }
}
