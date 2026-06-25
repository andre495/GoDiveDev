import Foundation

enum ActivityUploadRoute: Hashable, Sendable {
    case fitImportOptions
    case uddfImportOptions
    case macDiveImportGuide
}

extension ActivityUploadRoute: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.fitImportOptions, .fitImportOptions): true
        case (.uddfImportOptions, .uddfImportOptions): true
        case (.macDiveImportGuide, .macDiveImportGuide): true
        default: false
        }
    }
}
