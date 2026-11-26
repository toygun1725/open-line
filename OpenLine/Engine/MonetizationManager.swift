import Foundation
import Observation
import GoogleMobileAds
#if canImport(StoreKit)
import StoreKit
#endif

/// Native StoreKit 2 one-time All-Access ($0.99) manager & Rewarded Ad adapter for Act breaks.
@MainActor
@Observable
final class MonetizationManager {
    private(set) var productID: String
    private(set) var displayPrice: String = "$0.99"
    private(set) var isPurchaseInProgress: Bool = false
    private(set) var statusMessage: String?

    private let ads = RewardedAdPresenter()

    init(productID: String = "com.romitoygames.openline.all_access") {
        self.productID = productID
    }

    func configure(productID: String, fallbackPrice: String) async -> Bool {
        self.productID = productID
        self.displayPrice = fallbackPrice
        #if canImport(StoreKit)
        if let products = try? await Product.products(for: [productID]),
           let match = products.first {
            self.displayPrice = match.displayPrice
        }
        return await checkEntitlement()
        #else
        return false
        #endif
    }

    func checkEntitlement() async -> Bool {
        #if canImport(StoreKit)
        for await verification in Transaction.currentEntitlements {
            if case .verified(let transaction) = verification,
               transaction.productID == productID,
               transaction.revocationDate == nil {
                return true
            }
        }
        #endif
        return false
    }

    func purchaseAllAccess(language: AppLanguage) async -> Bool {
        #if canImport(StoreKit)
        isPurchaseInProgress = true
        statusMessage = nil
        defer { isPurchaseInProgress = false }

        guard let products = try? await Product.products(for: [productID]),
              let product = products.first else {
            statusMessage = language == .tr
                ? "Ürün şu an App Store’dan yüklenemedi. Tekrar deneyebilirsin."
                : "The App Store product is unavailable. Please try again."
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    return true
                }
                return false
            case .userCancelled:
                return false
            case .pending:
                statusMessage = language == .tr ? "Satın alma onayı bekleniyor..." : "Purchase pending approval..."
                return false
            @unknown default:
                return false
            }
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
        #else
        return false
        #endif
    }

    func restorePurchases(language: AppLanguage) async -> Bool {
        #if canImport(StoreKit)
        isPurchaseInProgress = true
        statusMessage = nil
        defer { isPurchaseInProgress = false }
        try? await AppStore.sync()
        let restored = await checkEntitlement()
        if !restored {
            statusMessage = language == .tr
                ? "Bu Apple hesabında daha önce alınmış Tam Erişim bulunamadı."
                : "No prior All-Access purchase found on this Apple Account."
        }
        return restored
        #else
        return false
        #endif
    }

    func watchRewardedAd() async -> RewardResult {
        await ads.present()
    }
}

@MainActor
private final class RewardedAdPresenter: NSObject, FullScreenContentDelegate {
    private var ad: RewardedAd?
    private var completion: CheckedContinuation<RewardResult, Never>?
    private var busy = false
    private var earned = false
    private var initialized = false

    func present() async -> RewardResult {
        guard !busy, let unit = Bundle.main.object(forInfoDictionaryKey: "OpenLineRewardedAdID") as? String else {
            return .unavailable
        }
        busy = true
        defer { busy = false }
        if !initialized {
            _ = await MobileAds.shared.start()
            initialized = true
        }
        do {
            let loaded = try await RewardedAd.load(with: unit, request: Request())
            ad = loaded
            earned = false
            loaded.fullScreenContentDelegate = self
            return await withCheckedContinuation { continuation in
                completion = continuation
                loaded.present(from: nil) { [weak self] in self?.earned = true }
            }
        } catch {
            return .unavailable
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finish(earned ? .earned : .cancelled)
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        finish(.unavailable)
    }

    private func finish(_ result: RewardResult) {
        let callback = completion
        completion = nil
        ad = nil
        callback?.resume(returning: result)
    }
}
