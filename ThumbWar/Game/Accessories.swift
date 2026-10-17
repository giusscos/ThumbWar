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
    /// Bought with coins earned in the Thumb Tour and from achievements.
    case coins(Int)
    /// Sold as an in-app purchase.
    case premium
}

struct Accessory: Identifiable, Equatable {
    let id: String
    let name: String
    let slot: AccessorySlot
    let unlock: Unlock
    var theme: AccessoryTheme = .classic

    var thumbnailName: String { "thumb_\(id)" }

    /// Rarity split: 1/5 free, 3/5 bought with earned coins, 1/5 premium.
    /// Coins only come from Thumb Tour stars and achievements, and the total on
    /// offer is just above what everything costs.
    static let all: [Accessory] = [
        // Classic hats
        Accessory(id: "cap", name: "Cap", slot: .hat, unlock: .free),
        Accessory(id: "party", name: "Party Hat", slot: .hat, unlock: .free),
        Accessory(id: "beanie", name: "Beanie", slot: .hat, unlock: .free),
        Accessory(id: "cowboy", name: "Cowboy", slot: .hat, unlock: .coins(150)),
        Accessory(id: "headphones", name: "Headphones", slot: .hat, unlock: .coins(150)),
        Accessory(id: "chef", name: "Chef", slot: .hat, unlock: .coins(250)),
        Accessory(id: "bunny", name: "Bunny Ears", slot: .hat, unlock: .coins(250)),
        Accessory(id: "wizard", name: "Wizard", slot: .hat, unlock: .coins(400)),
        Accessory(id: "viking", name: "Viking", slot: .hat, unlock: .coins(400)),
        Accessory(id: "pirate", name: "Pirate", slot: .hat, unlock: .coins(600)),
        Accessory(id: "tophat", name: "Top Hat", slot: .hat, unlock: .coins(600)),
        Accessory(id: "halo", name: "Halo", slot: .hat, unlock: .coins(600)),
        Accessory(id: "crown", name: "Crown", slot: .hat, unlock: .premium),
        Accessory(id: "unicorn", name: "Unicorn", slot: .hat, unlock: .premium),
        Accessory(id: "propeller", name: "Propeller", slot: .hat, unlock: .premium),
        // Classic face
        Accessory(id: "shades", name: "Shades", slot: .face, unlock: .free),
        Accessory(id: "mustache", name: "Mustache", slot: .face, unlock: .free),
        Accessory(id: "clown", name: "Clown Nose", slot: .face, unlock: .free),
        Accessory(id: "glasses", name: "Specs", slot: .face, unlock: .coins(150)),
        Accessory(id: "heart", name: "Heart Specs", slot: .face, unlock: .coins(250)),
        Accessory(id: "monocle", name: "Monocle", slot: .face, unlock: .coins(400)),
        Accessory(id: "eyepatch", name: "Eyepatch", slot: .face, unlock: .coins(600)),
        // Halloween event: coins or premium, nothing free
        Accessory(id: "witch", name: "Witch Hat", slot: .hat, unlock: .coins(350), theme: .halloween),
        Accessory(id: "cat", name: "Cat Ears", slot: .hat, unlock: .coins(350), theme: .halloween),
        Accessory(id: "devil", name: "Devil Horns", slot: .hat, unlock: .coins(350), theme: .halloween),
        Accessory(id: "mummy", name: "Mummy", slot: .hat, unlock: .coins(350), theme: .halloween),
        Accessory(id: "fangs", name: "Fangs", slot: .face, unlock: .coins(350), theme: .halloween),
        Accessory(id: "witchnose", name: "Witch Nose", slot: .face, unlock: .coins(350), theme: .halloween),
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
