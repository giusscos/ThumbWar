//
//  LockerView.swift
//  ThumbWar
//
//  Dress up each thumb. Locked items can be tried on in the preview, but only
//  unlocked ones can be equipped.
//

import SwiftUI

struct LockerView: View {
    let game: ThumbWarGame
    @Bindable var settings: GameSettings
    let feedback: GameFeedback
    let onDone: () -> Void

    @State private var side: Side = .left
    @Environment(\.verticalSizeClass) private var verticalSizeClass

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
                    lockNote
                }
                .padding(16)
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .onAppear { AccessoryLibrary.shared.loadAll() }
        .onDisappear { settings.preview = nil }
    }

    // MARK: Pieces

    @ViewBuilder private var header: some View {
        if landscape {
            HStack(spacing: 10) {
                title
                Spacer()
                sideTabs.frame(width: 190)
                done
            }
        } else {
            VStack(spacing: 10) {
                HStack {
                    title
                    Spacer()
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
        let locked = item.map { !settings.unlocks.isUnlocked($0) } ?? false
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

    @ViewBuilder private var lockNote: some View {
        if let preview = settings.preview, preview.side == side,
           let item = preview.loadout.ids.compactMap(Accessory.with(id:)).first(where: { !settings.unlocks.isUnlocked($0) }) {
            Text(lockText(item))
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(PuffySurface(shape: Capsule(), color: .purple, depth: 4))
                .padding(.bottom, 4)
        }
    }

    private func lockText(_ item: Accessory) -> String {
        switch item.unlock {
        case .free: return ""
        case .level(let n): return "Trying on \(item.name) · unlocks at level \(n)"
        case .premium: return "Trying on \(item.name) · premium item"
        case .seasonal: return "Trying on \(item.name) · free every October"
        }
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
        let (text, color): (String, Color) = switch unlock {
        case .level(let n): ("Lv \(n)", .purple)
        case .premium: ("★", .pink)
        case .seasonal: ("🎃 Oct", .orange)
        case .free: ("", .clear)
        }
        HStack(spacing: 3) {
            Image(systemName: "lock.fill").font(.system(size: 9, weight: .black))
            Text(text).font(.system(size: 11, weight: .black, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(color.gradient, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 2))
        .allowsHitTesting(false)
    }
}
