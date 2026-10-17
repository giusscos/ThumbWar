//
//  GameSettings.swift
//  ThumbWar
//

import Foundation
import Observation

enum SlamControl: String, CaseIterable, Identifiable {
    /// Lift the finger off the screen to slam.
    case lift
    /// Tap a slam button; during a pin both players mash it.
    case button

    var id: String { rawValue }
    var title: String { self == .lift ? "Lift finger" : "Slam button" }
}

enum MatchLength: String, CaseIterable, Identifiable {
    case seconds30, seconds60, seconds90, firstTo3

    var id: String { rawValue }
    var seconds: Float? {
        switch self {
        case .seconds30: 30
        case .seconds60: 60
        case .seconds90: 90
        case .firstTo3: nil
        }
    }
    var title: String {
        switch self {
        case .seconds30: "30 s"
        case .seconds60: "60 s"
        case .seconds90: "90 s"
        case .firstTo3: "3 pins"
        }
    }
}

enum CPULevel: String, CaseIterable, Identifiable {
    case easy, normal, hard

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

@Observable
final class GameSettings {
    var slamControl: SlamControl { didSet { defaults.set(slamControl.rawValue, forKey: Keys.slamControl) } }
    var matchLength: MatchLength { didSet { defaults.set(matchLength.rawValue, forKey: Keys.matchLength) } }
    var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.soundOn) } }
    var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.hapticsOn) } }
    var cpuLevel: CPULevel { didSet { defaults.set(cpuLevel.rawValue, forKey: Keys.cpuLevel) } }
    /// What each thumb wears, indexed by `Side.rawValue`.
    var loadouts: [Loadout] {
        didSet { defaults.set(try? JSONEncoder().encode(loadouts), forKey: Keys.loadouts) }
    }
    /// A try-on from the Locker (e.g. a locked item). Not saved.
    var preview: (side: Side, loadout: Loadout)?
    /// What the Thumb Tour rival wears, while a challenge is on. Not saved.
    var rivalLoadout: Loadout?

    func loadout(_ side: Side) -> Loadout { loadouts[side.rawValue] }

    /// Takes off anything the player doesn't own (catalog changes, refunds).
    func removeUnowned(_ owns: (Accessory) -> Bool) {
        let cleaned = loadouts.map { loadout in
            var kept = loadout
            for slot in AccessorySlot.allCases {
                if let item = Accessory.with(id: loadout[slot]), !owns(item) { kept[slot] = nil }
            }
            return kept
        }
        if cleaned != loadouts { loadouts = cleaned }
    }

    /// What the thumb should show right now: the try-on if there is one.
    func effectiveLoadout(_ side: Side) -> Loadout {
        if let preview, preview.side == side { return preview.loadout }
        if side == .right, let rivalLoadout { return rivalLoadout }
        return loadouts[side.rawValue]
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let slamControl = "settings.slamControl"
        static let matchLength = "settings.matchLength"
        static let soundOn = "settings.soundOn"
        static let hapticsOn = "settings.hapticsOn"
        static let cpuLevel = "settings.cpuLevel"
        static let loadouts = "settings.loadouts"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        slamControl = defaults.string(forKey: Keys.slamControl).flatMap(SlamControl.init) ?? .lift
        matchLength = defaults.string(forKey: Keys.matchLength).flatMap(MatchLength.init) ?? .seconds60
        soundOn = defaults.object(forKey: Keys.soundOn) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Keys.hapticsOn) as? Bool ?? true
        cpuLevel = defaults.string(forKey: Keys.cpuLevel).flatMap(CPULevel.init) ?? .normal
        loadouts = defaults.data(forKey: Keys.loadouts)
            .flatMap { try? JSONDecoder().decode([Loadout].self, from: $0) }
            .flatMap { $0.count == 2 ? $0 : nil }
            ?? [Loadout(hat: "cap"), Loadout(hat: "party")]
    }
}
