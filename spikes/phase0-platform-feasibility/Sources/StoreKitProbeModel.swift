import StoreKit
import SwiftUI

@MainActor
final class StoreKitProbeModel: ObservableObject {
    static let productIDs = [
        "app.sleepcompanion.spc.phase0spike.premium.monthly",
        "app.sleepcompanion.spc.phase0spike.premium.annual",
        "app.sleepcompanion.spc.phase0spike.premium.lifetime"
    ]

    @Published var products: [Product] = []
    @Published var entitledProductIDs: Set<String> = []
    @Published var status = "Products not loaded"

    func load() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
            await refreshEntitlements()
            status = products.isEmpty
                ? "No products returned. Check App Store Connect."
                : "Loaded \(products.count) products"
            await EvidenceLogger.shared.record(
                "storekit_products_loaded",
                details: [
                    "count": String(products.count),
                    "ids": products.map(\.id).joined(separator: ",")
                ]
            )
        } catch {
            status = "Product load failed: \(error.localizedDescription)"
            await recordFailure("storekit_product_load_failed", error)
        }
    }

    func purchase(_ product: Product) async {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await EvidenceLogger.shared.record(
                        "storekit_purchase_verified",
                        details: [
                            "product_id": transaction.productID,
                            "product_type": String(describing: transaction.productType),
                            "expiration": transaction.expirationDate?.ISO8601Format() ?? ""
                        ]
                    )
                    await transaction.finish()
                    status = "Verified: \(product.displayName)"
                    await refreshEntitlements()
                case .unverified(_, let error):
                    status = "Unverified transaction"
                    await recordFailure("storekit_purchase_unverified", error)
                }
            case .pending:
                status = "Purchase pending"
                await EvidenceLogger.shared.record(
                    "storekit_purchase_pending",
                    details: ["product_id": product.id]
                )
            case .userCancelled:
                status = "Purchase canceled"
                await EvidenceLogger.shared.record(
                    "storekit_purchase_canceled",
                    details: ["product_id": product.id]
                )
            @unknown default:
                status = "Unknown purchase result"
                await EvidenceLogger.shared.record(
                    "storekit_purchase_unknown",
                    details: ["product_id": product.id]
                )
            }
        } catch {
            status = "Purchase failed: \(error.localizedDescription)"
            await recordFailure("storekit_purchase_failed", error)
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            status = "Restore completed"
            await EvidenceLogger.shared.record("storekit_restore_completed")
        } catch {
            status = "Restore failed: \(error.localizedDescription)"
            await recordFailure("storekit_restore_failed", error)
        }
    }

    func refreshEntitlements() async {
        var current: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                current.insert(transaction.productID)
            }
        }
        entitledProductIDs = current
        await EvidenceLogger.shared.record(
            "storekit_entitlements_refreshed",
            details: ["ids": current.sorted().joined(separator: ",")]
        )
    }

    private func recordFailure(_ event: String, _ error: Error) async {
        await EvidenceLogger.shared.record(
            event,
            details: ["error": String(describing: error)]
        )
    }
}
