//
//  StoreManager.swift
//  Kosudoku
//
//  Created by Paul Kim on 3/31/26.
//

import StoreKit

/// Manages StoreKit 2 in-app purchases for consumable quickets
@Observable
@MainActor
class StoreManager {
    static let shared = StoreManager()
    
    // MARK: - Product IDs
    
    static let quickets5ProductID = "bejaflor.Kosudoku.quickets5"
    
    // MARK: - Observable State
    
    /// The loaded quickets product (nil until loaded)
    var quicketsProduct: Product?
    
    /// Whether a purchase is currently in progress
    var isPurchasing = false
    
    /// Error message from the last failed operation
    var errorMessage: String?
    
    /// Whether product loading has completed (success or failure)
    var hasAttemptedLoad = false
    
    // MARK: - Private
    
    private var transactionListener: Task<Void, Never>?
    
    private init() {}
    
    // MARK: - Transaction Listener
    
    /// Start listening for transaction updates. Call once on app launch.
    /// Catches transactions that were initiated but not yet finished
    /// (e.g., interrupted purchases, Ask to Buy approvals).
    func startTransactionListener() {
        transactionListener = Task.detached(priority: .background) {
            for await result in Transaction.updates {
                await self.handleTransactionResult(result)
            }
        }
    }
    
    func stopTransactionListener() {
        transactionListener?.cancel()
        transactionListener = nil
    }
    
    // MARK: - Load Products
    
    /// Fetch the quickets product from the App Store (or StoreKit config).
    /// Retries up to 3 times with a delay, since the StoreKit testing
    /// environment may not be ready immediately at app launch.
    func loadProducts() async {
        let maxRetries = 3
        for attempt in 1...maxRetries {
            do {
                print("🔄 StoreManager: requesting product ID '\(Self.quickets5ProductID)' (attempt \(attempt)/\(maxRetries))")
                let products = try await Product.products(for: [Self.quickets5ProductID])
                print("🔄 StoreManager: received \(products.count) products")
                for p in products {
                    print("   → id=\(p.id) displayName=\(p.displayName) type=\(p.type)")
                }
                quicketsProduct = products.first
                if quicketsProduct != nil {
                    hasAttemptedLoad = true
                    errorMessage = nil
                    print("✅ StoreManager: loaded product \(quicketsProduct!.displayName)")
                    return
                } else if attempt < maxRetries {
                    print("⚠️ StoreManager: 0 products returned, retrying after delay...")
                    try await Task.sleep(for: .seconds(2))
                }
            } catch {
                print("❌ StoreManager: failed to load products (attempt \(attempt)): \(error)")
                if attempt < maxRetries {
                    try? await Task.sleep(for: .seconds(2))
                }
            }
        }
        // All retries exhausted
        hasAttemptedLoad = true
        if quicketsProduct == nil {
            print("⚠️ StoreManager: quickets product not found after \(maxRetries) attempts")
            errorMessage = "Product not found. Tap Retry to try again."
        }
    }
    
    // MARK: - Purchase
    
    /// Purchase the 5-quickets consumable. Returns true on success.
    @discardableResult
    func purchaseQuickets() async -> Bool {
        guard let product = quicketsProduct else {
            errorMessage = "Product not available. Please try again later."
            return false
        }
        
        isPurchasing = true
        errorMessage = nil
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // Credit the quickets
                await creditQuickets(amount: 5)
                
                // Always finish consumable transactions
                await transaction.finish()
                
                isPurchasing = false
                return true
                
            case .userCancelled:
                isPurchasing = false
                return false
                
            case .pending:
                isPurchasing = false
                errorMessage = "Purchase is pending approval."
                return false
                
            @unknown default:
                isPurchasing = false
                return false
            }
        } catch {
            isPurchasing = false
            errorMessage = "Purchase failed: \(error.localizedDescription)"
            print("❌ StoreManager: purchase error: \(error)")
            return false
        }
    }
    
    // MARK: - Private Helpers
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
    
    private func handleTransactionResult(_ result: VerificationResult<Transaction>) async {
        do {
            let transaction = try checkVerified(result)
            
            if transaction.productID == Self.quickets5ProductID {
                await creditQuickets(amount: 5)
            }
            
            await transaction.finish()
        } catch {
            print("⚠️ StoreManager: unverified transaction: \(error)")
        }
    }
    
    /// Add quickets to the current user profile and sync to CloudKit.
    private func creditQuickets(amount: Int) async {
        guard let profile = CloudKitService.shared.currentUserProfile else {
            print("⚠️ StoreManager: no current profile to credit quickets")
            return
        }
        
        profile.quickets += amount
        print("🎟️ StoreManager: credited \(amount) quickets → total \(profile.quickets)")
        
        // Sync to CloudKit. No revert on failure — the user already paid.
        // CloudKit will sync on next profile save from any part of the app.
        do {
            try await CloudKitService.shared.saveUserProfile(profile)
        } catch {
            print("⚠️ StoreManager: failed to sync quickets to CloudKit: \(error.localizedDescription)")
        }
    }
}
