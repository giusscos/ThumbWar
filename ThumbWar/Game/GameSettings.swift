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

@Observable
final class GameSettings {
    var slamControl: SlamControl { didSet { defaults.set(slamControl.rawValue, forKey: Keys.slamControl) } }
    var matchLength: MatchLength { didSet { defaults.set(matchLength.rawValue, forKey: Keys.matchLength) } }
    var soundOn: Bool { didSet { defaults.set(soundOn, forKey: Keys.soundOn) } }
    var hapticsOn: Bool { didSet { defaults.set(hapticsOn, forKey: Keys.hapticsOn) } }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let slamControl = "settings.slamControl"
        static let matchLength = "settings.matchLength"
        static let soundOn = "settings.soundOn"
        static let hapticsOn = "settings.hapticsOn"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        slamControl = defaults.string(forKey: Keys.slamControl).flatMap(SlamControl.init) ?? .lift
        matchLength = defaults.string(forKey: Keys.matchLength).flatMap(MatchLength.init) ?? .seconds60
        soundOn = defaults.object(forKey: Keys.soundOn) as? Bool ?? true
        hapticsOn = defaults.object(forKey: Keys.hapticsOn) as? Bool ?? true
    }
}
