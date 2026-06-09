import CryptoKit
import Foundation

/// Image metadata required by Fishial's direct-upload API (**`tutor.adoc`**).
struct FishialImageBlobMetadata: Equatable, Sendable {
    let filename: String
    let contentType: String
    let byteSize: Int
    /// Base64-encoded MD5 digest of the raw bytes (Fishial **`checksum`** field).
    let checksumBase64MD5: String

    nonisolated static let defaultJPEGFilename = "dive-media.jpg"
    nonisolated static let defaultJPEGContentType = "image/jpeg"

    nonisolated static func fromJPEGData(
        _ data: Data,
        filename: String = defaultJPEGFilename
    ) -> FishialImageBlobMetadata {
        let baseName = (filename as NSString).lastPathComponent
        return FishialImageBlobMetadata(
            filename: baseName.isEmpty ? defaultJPEGFilename : baseName,
            contentType: defaultJPEGContentType,
            byteSize: data.count,
            checksumBase64MD5: base64MD5Checksum(for: data)
        )
    }

    nonisolated static func base64MD5Checksum(for data: Data) -> String {
        let digest = Insecure.MD5.hash(data: data)
        return Data(digest).base64EncodedString()
    }
}
