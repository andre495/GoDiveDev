import SwiftUI

#if canImport(UIKit)
import UIKit

extension View {
    /// Publishes live **`UITabBar`** clearance via **`RootTabBarClearanceMetrics.HeightKey`**.
    func rootTabBarClearanceReader(enabled: Bool = true) -> some View {
        overlay(alignment: .bottom) {
            if enabled {
                RootTabBarClearanceReaderBridge()
            }
        }
    }
}

private struct RootTabBarClearanceReaderBridge: View {
    @State private var clearance: CGFloat = 0

    var body: some View {
        RootTabBarClearanceReaderRepresentable(onClearance: { clearance = $0 })
            .frame(maxWidth: .infinity, maxHeight: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .preference(key: RootTabBarClearanceMetrics.HeightKey.self, value: clearance)
    }
}

private struct RootTabBarClearanceReaderRepresentable: UIViewRepresentable {
    let onClearance: (CGFloat) -> Void

    func makeUIView(context: Context) -> RootTabBarClearanceMeasurerView {
        let view = RootTabBarClearanceMeasurerView()
        view.onClearanceChange = onClearance
        return view
    }

    func updateUIView(_ uiView: RootTabBarClearanceMeasurerView, context: Context) {
        uiView.onClearanceChange = onClearance
        uiView.setNeedsLayout()
    }
}

private final class RootTabBarClearanceMeasurerView: UIView {
    var onClearanceChange: ((CGFloat) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        remeasure()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        remeasure()
    }

    private func remeasure() {
        guard let clearance = RootTabBarLayoutMeasurement.measuredClearanceAboveTabBar(from: self) else {
            return
        }
        onClearanceChange?(clearance)
    }
}
#endif
