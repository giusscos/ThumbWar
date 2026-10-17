//
//  Store.swift
//  ThumbWar
//
//  Premium items sold as non-consumable in-app purchases (StoreKit 2). The App
//  Store is the source of truth: on launch and after a restore, the profile's
//  premium items are synced to the current entitlements, so refunds take them away.
//

import Foundation
import Observation
import StoreKit
import SwiftUI

@MainActor
@Observable
final class Store {
    enum Status: Equatable {
        case idle
        case purchasing
        /// Waiting on Ask to Buy or another approval; the item arrives through `Transaction.updates`.
        case pending
        case failed(String)
    }

    /// Products keyed by accessory id.
    private(set) var products: [String: Product] = [:]
    private(set) var isLoading = false
    /// Purchase status per accessory id.
    private(set) var status: [String: Status] = [:]
    private(set) var isRestoring = false
    private(set) var restoreMessage: String?

    /// Called whenever purchases add or remove items (achievements, equipped items).
    @ObservationIgnored var onOwnedChange: (() -> Void)?
    @ObservationIgnored private let profile: Profile
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(profile: Profile) {
        self.profile = profile
    }

    static func productID(for item: Accessory) -> String { "com.giusscos.ThumbWar.item.\(item.id)" }

    private static func item(forProductID id: String) -> Accessory? {
        Accessory.all.first { $0.unlock == .premium && productID(for: $0) == id }
    }

    /// Starts listening for transactions and catches up with the App Store.
    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
            }
        }
        Task {
            await loadProducts()
            await syncEntitlements()
        }
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        let ids = Accessory.all.filter { $0.unlock == .premium }.map(Self.productID)
        guard let loaded = try? await Product.products(for: ids) else { return }
        var byItem: [String: Product] = [:]
        for product in loaded {
            if let item = Self.item(forProductID: product.id) { byItem[item.id] = product }
        }
        products = byItem
    }

    func status(of item: Accessory) -> Status { status[item.id] ?? .idle }

    /// Buys an item through the scene's purchase action. Returns true once it's owned.
    func purchase(_ item: Accessory, using purchase: PurchaseAction) async -> Bool {
        guard let product = products[item.id] else {
            status[item.id] = .failed("The store isn't available right now.")
            return false
        }
        status[item.id] = .purchasing
        do {
            switch try await purchase(product) {
            case .success(.verified(let transaction)):
                grant(transaction)
                await transaction.finish()
                status[item.id] = nil
                return true
            case .success(.unverified):
                status[item.id] = .failed("The purchase couldn't be verified.")
            case .pending:
                status[item.id] = .pending
            case .userCancelled:
                status[item.id] = nil
            @unknown default:
                status[item.id] = nil
            }
        } catch {
            status[item.id] = .failed(error.localizedDescription)
        }
        return false
    }

    /// Asks the App Store for the latest purchases, then syncs them.
    func restore() async {
        isRestoring = true
        restoreMessage = nil
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            restoreMessage = "Couldn't reach the App Store. Try again later."
            return
        }
        let before = profile.data.owned
        await syncEntitlements()
        let premium = Set(Accessory.all.filter { $0.unlock == .premium }.map(\.id))
        let owned = profile.data.owned.intersection(premium)
        restoreMessage = owned.isEmpty ? "No purchases to restore."
            : (owned.isSubset(of: before) ? "All your purchases are here." : "Purchases restored!")
    }

    // MARK: Transactions

    private func handle(_ result: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate != nil {
            revoke(transaction.productID)
        } else {
            grant(transaction)
            if let item = Self.item(forProductID: transaction.productID) { status[item.id] = nil }
        }
        await transaction.finish()
    }

    private func grant(_ transaction: StoreKit.Transaction) {
        guard let item = Self.item(forProductID: transaction.productID), !profile.owns(item) else { return }
        profile.update { $0.owned.insert(item.id) }
        onOwnedChange?()
    }

    private func revoke(_ productID: String) {
        guard let item = Self.item(forProductID: productID), profile.owns(item) else { return }
        profile.update { $0.owned.remove(item.id) }
        onOwnedChange?()
    }

    /// Makes the profile's premium items match what the App Store says is owned.
    private func syncEntitlements() async {
        var entitled: Set<String> = []
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil,
                  let item = Self.item(forProductID: transaction.productID) else { continue }
            entitled.insert(item.id)
        }
        let premium = Set(Accessory.all.filter { $0.unlock == .premium }.map(\.id))
        let owned = profile.data.owned.subtracting(premium).union(entitled)
        guard owned != profile.data.owned else { return }
        profile.update { $0.owned = owned }
        onOwnedChange?()
    }
}
