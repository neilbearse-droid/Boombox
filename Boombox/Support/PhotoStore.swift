import UIKit

/// Tile photos are copied into Application Support and referenced by filename,
/// so the app never depends on Photos library access after picking.
enum PhotoStore {
    static var directory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TilePhotos", isDirectory: true)
    }

    /// Saves picked image data as a square-cropped JPEG. Returns the filename.
    static func save(_ data: Data) -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let squared = squareCrop(image, maxSide: 600)
        guard let jpeg = squared.jpegData(compressionQuality: 0.85) else { return nil }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true)
            let filename = UUID().uuidString + ".jpg"
            try jpeg.write(to: directory.appendingPathComponent(filename))
            return filename
        } catch {
            return nil
        }
    }

    static func load(_ filename: String) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(filename).path)
    }

    static func delete(_ filename: String) {
        try? FileManager.default.removeItem(
            at: directory.appendingPathComponent(filename))
    }

    private static func squareCrop(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let side = min(image.size.width, image.size.height)
        let target = min(side, maxSide)
        let scale = target / side
        let scaledSize = CGSize(
            width: image.size.width * scale, height: image.size.height * scale)
        let origin = CGPoint(
            x: (target - scaledSize.width) / 2,
            y: (target - scaledSize.height) / 2)
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: target, height: target))
        return renderer.image { _ in
            image.draw(in: CGRect(origin: origin, size: scaledSize))
        }
    }
}
