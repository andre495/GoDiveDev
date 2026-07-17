import Foundation

extension Dictionary {
    /// Builds a dictionary from key-value pairs, keeping the **last** value when keys collide.
    ///
    /// Prefer this over **`Dictionary(uniqueKeysWithValues:)`** for CloudKit / relationship-sourced
    /// collections where duplicate IDs can appear — uniqueKeys traps with **`EXC_BREAKPOINT`**.
    nonisolated init(godiveUniquingKeysWithValues keysAndValues: some Sequence<(Key, Value)>) {
        self.init()
        for (key, value) in keysAndValues {
            self[key] = value
        }
    }
}
