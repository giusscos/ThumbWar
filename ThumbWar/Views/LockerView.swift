//
//  LockerView.swift
//  ThumbWar
//
//  Dress up each thumb, and the shop: any item can be tried on in the preview;
//  coin items are bought with coins and premium ones as in-app purchases, right here.
//

import StoreKit
import SwiftUI

struct LockerView: View {
    let game: ThumbWarGame
    @Bindable var settings: GameSettings
    let feedback: GameFeedback
    let onDone: () -> Void

    @State private var side: Side = .left
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(Career.self) private var career
    @Environment(Store.self) private var store
    @Environment(\.purchase) private var purchase

    private var landscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            PuffyCard {
                VStack(spacing: 12) {
                    header
                    if landscape {
                        HStack(spacing: 14) {
                            preview.frame(width: 220)
                            catalog
                        }
                    } else {
                        VStack(spacing: 12) {
                            preview.frame(height: 230)
                            catalog
                        }
                    }
                    shopBar
                }
                .padding(16)
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .onAppear { AccessoryLibrary.shared.loadAll() }
        .task { await store.loadProducts() }
        .onDisappear { settings.preview = nil }
    }

    // MARK: Pieces

    @ViewBuilder private var header: some View {
        if landscape {
            HStack(spacing: 10) {
                title
                CoinPill(coins: career.profile.coins)
                Spacer()
                sideTabs.frame(width: 190)
                done
            }
        } else {
            VStack(spacing: 10) {
                HStack {
                    title
                    Spacer()
                    CoinPill(coins: career.profile.coins)
                    done
                }
                sideTabs
            }
        }
    }

    private var title: some View {
        PuffyText(text: "Locker", size: 34, color: .orange)
    }

    private var done: some View {
        PuffyButton(title: "Done", color: .green, compact: true) {
            feedback.tap()
            onDone()
        }
        .fixedSize()
    }

    private var sideTabs: some View {
        HStack(spacing: 10) {
            ForEach(Side.allCases, id: \.self) { s in
                PuffyChip(title: game.mode == .vsCPU && s == .right ? "CPU" : s.name, selected: side == s) {
                    feedback.tap()
                    settings.preview = nil
                    side = s
                }
            }
        }
    }

    private var preview: some View {
        ArenaView(game: game, settings: settings, rig: .locker(side), drivesSimulation: false)
            .id("locker-\(side)")
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 4))
    }

    private var catalog: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(sections, id: \.title) { section in
                    Text(section.title.uppercased())
                        .font(.system(.footnote, design: .rounded, weight: .black))
                        .foregroundStyle(section.theme == .halloween ? Color.orange : PuffyPalette.ink.opacity(0.75))
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 82), spacing: 10)], spacing: 10) {
                        if let slot = section.noneSlot { tile(nil, slot: slot) }
                        ForEach(section.items) { item in
                            tile(item, slot: item.slot)
                        }
                    }
                }
            }
            .padding(4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeFade()
    }

    private struct Section {
        let title: String
        let theme: AccessoryTheme
        let items: [Accessory]
        /// Sections for a single slot start with a "None" tile.
        let noneSlot: AccessorySlot?
    }

    private var sections: [Section] {
        let classic = Accessory.all.filter { $0.theme == .classic }
        return [
            Section(title: "Hats", theme: .classic, items: classic.filter { $0.slot == .hat }, noneSlot: .hat),
            Section(title: "Face", theme: .classic, items: classic.filter { $0.slot == .face }, noneSlot: .face),
            Section(title: "Halloween 🎃", theme: .halloween, items: Accessory.all.filter { $0.theme == .halloween }, noneSlot: nil),
        ]
    }

    private func tile(_ item: Accessory?, slot: AccessorySlot) -> some View {
        let shown = settings.effectiveLoadout(side)[slot]
        let equipped = settings.loadout(side)[slot]
        let locked = item.map { !career.profile.owns($0) } ?? false
        return ItemTile(item: item, isShown: shown == item?.id, isEquipped: equipped == item?.id, locked: locked) {
            feedback.tap()
            if locked, let item {
                var tryOn = settings.loadout(side)
                tryOn[slot] = item.id
                settings.preview = (side, tryOn)
            } else {
                settings.preview = nil
                settings.loadouts[side.rawValue][slot] = item?.id
            }
        }
    }

    /// Shown while trying on an item you don't own: buy it with coins, or see how to get it.
    @ViewBuilder private var shopBar: some View {
        if let preview = settings.preview, preview.side == side,
           let item = preview.loadout.ids.compactMap(Accessory.with(id:)).first(where: { !career.profile.owns($0) }) {
            HStack(spacing: 12) {
                switch item.unlock {
                case .coins(let price):
                    let short = price - career.profile.coins
                    Text(short > 0 ? "\(item.name) · \(short) more coins needed" : "Make \(item.name) yours?")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .foregroundStyle(PuffyPalette.ink)
                    Button {
                        buy(item)
                    } label: {
                        HStack(spacing: 6) {
                            Text("Buy")
                            CoinIcon(size: 20)
                            Text("\(price)")
                        }
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .padding(.horizontal, 16).padding(.vertical, 9)
                    }
                    .buttonStyle(.puffy(short > 0 ? Color(white: 0.7) : .green))
                    .disabled(short > 0)
                case .premium:
                    premiumOffer(item)
                case .free:
                    EmptyView()
                }
            }
        }
    }

    /// Premium items: the App Store price on a puffy Buy button, plus how the purchase is going.
    @ViewBuilder private func premiumOffer(_ item: Accessory) -> some View {
        let status = store.status(of: item)
        let product = store.products[item.id]
        Group {
            switch status {
            case .pending: Text("Waiting for approval…")
            case .failed(let message): Text(message)
            case .idle, .purchasing:
                Text(product == nil && !store.isLoading ? "Store unavailable · try again later" : "\(item.name) · premium item")
            }
        }
        .font(.system(.subheadline, design: .rounded, weight: .heavy))
        .foregroundStyle(PuffyPalette.ink)
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        Button {
            feedback.tap()
            Task {
                if await store.purchase(item, using: purchase) { bought(item) }
            }
        } label: {
            // The spinner sits over the hidden label so the button keeps its size.
            HStack(spacing: 6) {
                Image(systemName: "star.fill").font(.system(size: 15, weight: .black))
                Text("Buy")
                if let product { Text(product.displayPrice) }
            }
            .opacity(status == .purchasing ? 0 : 1)
            .overlay { if status == .purchasing { ProgressView().tint(.white) } }
            .font(.system(.headline, design: .rounded, weight: .black))
            .padding(.horizontal, 16).padding(.vertical, 9)
        }
        .buttonStyle(.puffy(product == nil || status == .pending ? Color(white: 0.7) : .pink))
        .disabled(product == nil || status == .purchasing || status == .pending)
    }

    private func buy(_ item: Accessory) {
        guard career.profile.buy(item) else { return }
        bought(item)
    }

    /// Equips a newly owned item.
    private func bought(_ item: Accessory) {
        feedback.play("point")
        settings.loadouts[side.rawValue][item.slot] = item.id
        settings.preview = nil
        career.checkAchievements()
    }
}

private struct ItemTile: View {
    let item: Accessory?
    let isShown: Bool
    let isEquipped: Bool
    let locked: Bool
    let action: () -> Void

    var body: some View {
        let color: Color = isEquipped ? .orange : (isShown ? .purple : .white)
        Button(action: action) {
            VStack(spacing: 2) {
                Group {
                    if let item, let image = UIImage(named: item.thumbnailName) {
                        Image(uiImage: image).resizable().scaledToFit()
                    } else {
                        Image(systemName: "nosign")
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundStyle(PuffyPalette.ink.opacity(0.4))
                    }
                }
                .frame(width: 58, height: 58)
                .opacity(locked ? 0.55 : 1)
                Text(item?.name ?? "None")
                    .font(.system(.caption, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PuffyButtonStyle(color: color, shape: RoundedRectangle(cornerRadius: 18, style: .continuous),
                                      textColor: color == .white ? PuffyPalette.ink : .white, depth: 5))
        .overlay(alignment: .topTrailing) {
            if let item, locked { LockBadge(unlock: item.unlock).offset(x: 4, y: -6) }
        }
    }
}

private struct LockBadge: View {
    let unlock: Unlock

    var body: some View {
        HStack(spacing: 3) {
            switch unlock {
            case .coins(let price):
                CoinIcon(size: 13)
                Text("\(price)").font(.system(size: 11, weight: .black, design: .rounded))
            case .premium:
                Image(systemName: "star.fill").font(.system(size: 10, weight: .black))
            case .free:
                EmptyView()
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background((unlock == .premium ? Color.pink : PuffyPalette.ink).gradient, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 2))
        .allowsHitTesting(false)
    }
}
