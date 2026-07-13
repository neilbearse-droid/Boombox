import Foundation
import Observation
import StoreKit

/// The tip jar: three consumable products, no paywall, nothing gated.
/// Every feature in the app is free; tips exist only behind the parent PIN.
@MainActor
@Observable
final class TipJarStore {
    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    private(set) var didJustTip = false
    private(set) var loadFailed = false

    /// Product IDs follow the bundle ID, so they survive a bundle-ID change:
    /// <bundle-id>.tip.small / .tip.medium / .tip.large — create the same
    /// three consumable IAPs in App Store Connect.
    static var productIDs: [String] {
        let base = Bundle.main.bundleIdentifier ?? "com.example.Boombox"
        return ["\(base).tip.small", "\(base).tip.medium", "\(base).tip.large"]
    }

    nonisolated init() {}

    func load() async {
        do {
            let items = try await Product.products(for: Self.productIDs)
            products = items.sorted { $0.price < $1.price }
            loadFailed = products.isEmpty
        } catch {
            loadFailed = true
        }
    }

    func tip(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
                case .verified(let transaction) = verification
            {
                await transaction.finish()
                didJustTip = true
            }
        } catch {
            // Cancelled or failed — no error UI needed for a tip.
        }
    }

    /// Finishes any stray transactions (e.g. interrupted purchases).
    func observeTransactions() async {
        for await update in Transaction.updates {
            if case .verified(let transaction) = update {
                await transaction.finish()
            }
        }
    }
}
