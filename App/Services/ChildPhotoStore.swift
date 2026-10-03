import Foundation
import UIKit

/// Children's photos, kept in the app's own storage on this device only
/// (never in the shared App Group, iCloud or Apple Health).
enum ChildPhotoStore {
    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ChildPhotos", isDirectory: true)
    }

    private static func url(for id: UUID) -> URL {
        folder.appendingPathComponent("\(id.uuidString).jpg")
    }

    static func load(_ id: UUID) -> UIImage? {
        UIImage(contentsOfFile: url(for: id).path)
    }

    /// Saves a downsized copy, with metadata such as location stripped by re-encoding.
    @discardableResult
    static func save(_ data: Data, for id: UUID) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        let side: CGFloat = 600
        let scale = min(1, side / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: size).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return false }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return (try? jpeg.write(to: url(for: id), options: [.atomic, .completeFileProtection])) != nil
    }

    static func delete(_ id: UUID) {
        try? FileManager.default.removeItem(at: url(for: id))
    }
}
