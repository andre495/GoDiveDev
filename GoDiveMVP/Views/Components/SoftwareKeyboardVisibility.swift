import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Publishes software-keyboard visibility for layouts that adapt above the keyboard.
struct SoftwareKeyboardVisibilityModifier: ViewModifier {
    @Binding var isVisible: Bool
    @Binding var overlapHeight: CGFloat

    func body(content: Content) -> some View {
        content
            #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                withAnimation(Self.keyboardAnimation(from: notification)) {
                    isVisible = true
                    overlapHeight = Self.keyboardOverlapHeight(from: notification)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                withAnimation(Self.keyboardAnimation(from: notification)) {
                    isVisible = false
                    overlapHeight = 0
                }
            }
            #endif
    }

    #if canImport(UIKit)
    private static func keyboardOverlapHeight(from notification: Notification) -> CGFloat {
        guard
            let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else {
            return 0
        }
        guard let window = keyWindow else {
            return max(0, frame.height)
        }
        let intersection = frame.intersection(window.bounds)
        return max(0, intersection.height)
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func keyboardAnimation(from notification: Notification) -> Animation {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
        let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? 0
        let curve = UIView.AnimationCurve(rawValue: Int(curveRaw)) ?? .easeInOut
        switch curve {
        case .easeInOut:
            return .easeInOut(duration: duration)
        case .easeIn:
            return .easeIn(duration: duration)
        case .easeOut:
            return .easeOut(duration: duration)
        case .linear:
            return .linear(duration: duration)
        @unknown default:
            return .easeInOut(duration: duration)
        }
    }
    #endif
}

extension View {
    func softwareKeyboardVisibility(_ isVisible: Binding<Bool>, overlapHeight: Binding<CGFloat>) -> some View {
        modifier(SoftwareKeyboardVisibilityModifier(isVisible: isVisible, overlapHeight: overlapHeight))
    }
}
