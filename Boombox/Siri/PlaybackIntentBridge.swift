import Foundation

/// A tiny hand-off between an App Intent (which may run in a separate
/// process) and the running app. The intent writes the tile id it wants
/// played; RootView drains it on foreground and plays through the normal
/// tap path — so schedules, limits, and the explicit filter all still apply.
///
/// Voice can only ever request a tile that already exists, never arbitrary
/// music: the intent's parameter is a constrained TileEntity drawn from the
/// configured tiles.
enum PlaybackIntentBridge {
    private static let key = "boombox.pendingSiriTileID"

    static func requestPlay(tileID: UUID) {
        UserDefaults.standard.set(tileID.uuidString, forKey: key)
    }

    /// Returns and clears any pending request.
    static func consumePendingTileID() -> UUID? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        UserDefaults.standard.removeObject(forKey: key)
        return UUID(uuidString: raw)
    }
}
