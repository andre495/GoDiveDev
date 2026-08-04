import Foundation
import SwiftUI

/// Prevents laggy multi-taps from stacking the same `NavigationStack` destination on itself.
enum NavigationStackPushCoalescing: Sendable {
    /// Appends `route` only when it is not already the top of `path`.
    @discardableResult
    static func append<Route: Equatable>(_ route: Route, to path: inout [Route]) -> Bool {
        guard path.last != route else { return false }
        path.append(route)
        return true
    }

    /// Collapses runs of identical consecutive routes (safety net for `NavigationLink(value:)`).
    static func coalescedByRemovingConsecutiveDuplicates<Route: Equatable>(
        _ path: [Route]
    ) -> [Route] {
        guard path.count > 1 else { return path }
        var result: [Route] = []
        result.reserveCapacity(path.count)
        for route in path {
            if result.last != route {
                result.append(route)
            }
        }
        return result
    }

    /// Assigns an optional `navigationDestination(item:)` value only when idle (`nil`).
    @discardableResult
    static func assignIfNil<Value>(_ value: Value, to current: inout Value?) -> Bool {
        guard current == nil else { return false }
        current = value
        return true
    }

    /// Sets an optional destination unless it already equals `value` (blocks laggy re-taps of the same page).
    @discardableResult
    static func assignUnlessDuplicate<Value: Equatable>(_ value: Value, to current: inout Value?) -> Bool {
        guard current != value else { return false }
        current = value
        return true
    }
}

extension View {
    /// Strips consecutive duplicate trailing routes after `NavigationLink` / system path mutations.
    func coalescesNavigationStackPathDuplicates<Route: Equatable>(
        _ path: Binding<[Route]>
    ) -> some View {
        onChange(of: path.wrappedValue) { _, newValue in
            let coalesced = NavigationStackPushCoalescing.coalescedByRemovingConsecutiveDuplicates(newValue)
            guard coalesced != newValue else { return }
            path.wrappedValue = coalesced
        }
    }
}
