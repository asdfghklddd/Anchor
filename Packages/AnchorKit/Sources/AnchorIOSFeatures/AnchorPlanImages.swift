#if os(iOS)
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Keep photo bytes out of the event log and device-to-device transport.
enum AnchorPlanImages {
    static func preparedData(_ data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600
              ] as CFDictionary) else { throw CocoaError(.fileReadCorruptFile) }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return output as Data
    }

    static func save(_ images: [Data], goalID: UUID) throws -> [String] {
        guard !images.isEmpty else { return [] }
        let folder = try directory(goalID: goalID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return try images.enumerated().map { index, data in
            let name = "reference-\(index + 1).jpg"
            try data.write(to: folder.appending(path: name), options: .atomic)
            return name
        }
    }

    static func load(goalID: UUID, names: [String]) -> [Data] {
        guard let folder = try? directory(goalID: goalID) else { return [] }
        return names.filter { $0 == URL(fileURLWithPath: $0).lastPathComponent }
            .compactMap { try? Data(contentsOf: folder.appending(path: $0)) }
    }

    private static func directory(goalID: UUID) throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appending(path: "Anchor/PlanImages/\(goalID.uuidString)", directoryHint: .isDirectory)
    }
}
#endif
