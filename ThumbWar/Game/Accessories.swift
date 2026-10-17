//
//  Accessories.swift
//  ThumbWar
//
//  The wearable catalog. Models live in ThumbWar/Accessories/<id>.usdz and are
//  authored in Art/ThumbWarAccessories.blend in "head units": the thumb tip is a
//  sphere of radius 1, the face looks toward +Z and up is +Y.
//

import Foundation

enum AccessorySlot: String, CaseIterable, Identifiable {
    case hat, face

    var id: String { rawValue }
    var title: String { self == .hat ? "Hats" : "Face" }
}

enum AccessoryTheme: String {
    case classic, halloween
}

enum Unlock: Equatable {
    case free
    /// Earned by reaching this level in the challenge mode.
    case level(Int)
    /// Sold as an in-app purchase.
    case premium
    /// Free to wear during this month every year (10 = October).
    case seasonal(month: Int)
}

struct Accessory: Identifiable, Equatable {
    let id: String
    let name: String
    let slot: AccessorySlot
    let unlock: Unlock
    var theme: AccessoryTheme = .classic

    var thumbnailName: String { "thumb_\(id)" }

    /// Rarity split: 1/5 free, 3/5 unlocked by playing (levels 1–20, or the
    /// Halloween season), 1/5 premium purchases. Listed in unlock order.
    static let all: [Accessory] = [
        // Classic hats
        Accessory(id: "cap", name: "Cap", slot: .hat, unlock: .free),
        Accessory(id: "party", name: "Party Hat", slot: .hat, unlock: .free),
        Accessory(id: "beanie", name: "Beanie", slot: .hat, unlock: .free),
        Accessory(id: "cowboy", name: "Cowboy", slot: .hat, unlock: .level(2)),
        Accessory(id: "headphones", name: "Headphones", slot: .hat, unlock: .level(4)),
        Accessory(id: "chef", name: "Chef", slot: .hat, unlock: .level(5)),
        Accessory(id: "bunny", name: "Bunny Ears", slot: .hat, unlock: .level(8)),
        Accessory(id: "wizard", name: "Wizard", slot: .hat, unlock: .level(10)),
        Accessory(id: "viking", name: "Viking", slot: .hat, unlock: .level(12)),
        Accessory(id: "pirate", name: "Pirate", slot: .hat, unlock: .level(14)),
        Accessory(id: "tophat", name: "Top Hat", slot: .hat, unlock: .level(17)),
        Accessory(id: "halo", name: "Halo", slot: .hat, unlock: .level(20)),
        Accessory(id: "crown", name: "Crown", slot: .hat, unlock: .premium),
        Accessory(id: "unicorn", name: "Unicorn", slot: .hat, unlock: .premium),
        Accessory(id: "propeller", name: "Propeller", slot: .hat, unlock: .premium),
        // Classic face
        Accessory(id: "shades", name: "Shades", slot: .face, unlock: .free),
        Accessory(id: "mustache", name: "Mustache", slot: .face, unlock: .free),
        Accessory(id: "clown", name: "Clown Nose", slot: .face, unlock: .free),
        Accessory(id: "glasses", name: "Specs", slot: .face, unlock: .level(3)),
        Accessory(id: "heart", name: "Heart Specs", slot: .face, unlock: .level(6)),
        Accessory(id: "monocle", name: "Monocle", slot: .face, unlock: .level(9)),
        Accessory(id: "eyepatch", name: "Eyepatch", slot: .face, unlock: .level(15)),
        // Halloween: unlocked every October, plus premium costumes
        Accessory(id: "witch", name: "Witch Hat", slot: .hat, unlock: .seasonal(month: 10), theme: .halloween),
        Accessory(id: "cat", name: "Cat Ears", slot: .hat, unlock: .seasonal(month: 10), theme: .halloween),
        Accessory(id: "devil", name: "Devil Horns", slot: .hat, unlock: .seasonal(month: 10), theme: .halloween),
        Accessory(id: "mummy", name: "Mummy", slot: .hat, unlock: .seasonal(month: 10), theme: .halloween),
        Accessory(id: "fangs", name: "Fangs", slot: .face, unlock: .seasonal(month: 10), theme: .halloween),
        Accessory(id: "witchnose", name: "Witch Nose", slot: .face, unlock: .seasonal(month: 10), theme: .halloween),
        Accessory(id: "pumpkin", name: "Pumpkin", slot: .hat, unlock: .premium, theme: .halloween),
        Accessory(id: "frankenstein", name: "Monster", slot: .hat, unlock: .premium, theme: .halloween),
        Accessory(id: "spider", name: "Spider", slot: .hat, unlock: .premium, theme: .halloween),
    ]

    static func with(id: String?) -> Accessory? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

/// What one player's thumb is wearing.
struct Loadout: Equatable, Codable {
    var hat: String?
    var face: String?

    subscript(slot: AccessorySlot) -> String? {
        get { slot == .hat ? hat : face }
        set { if slot == .hat { hat = newValue } else { face = newValue } }
    }

    var ids: [String] { [hat, face].compactMap { $0 } }
}

/// Which items the player owns. Levels and purchases don't exist yet, so only
/// free items are unlocked; this is the single place to extend.
struct Unlocks {
    var playerLevel = 0
    var purchased: Set<String> = []

    func isUnlocked(_ item: Accessory, on date: Date = .now) -> Bool {
        switch item.unlock {
        case .free: true
        case .level(let n): playerLevel >= n
        case .premium: purchased.contains(item.id)
        case .seasonal(let month): Calendar.current.component(.month, from: date) == month
        }
    }
}
