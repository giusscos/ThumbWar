//
//  Profile.swift
//  ThumbWar
//
//  The player's saved progress: coins, owned items, Thumb Tour stars,
//  achievements and lifetime stats. Stored on the device for now.
//

import Foundation
import Observation

struct ProfileData: Codable, Equatable {
    var coins = 0
    /// Items bought with coins or purchased.
    var owned: Set<String> = []
    /// Challenge id → bitmask of the stars earned (bit 0 = win, 1 and 2 = goals).
    var stars: [Int: Int] = [:]
    var achievements: Set<String> = []

    // Lifetime stats (matches against the CPU, including the Thumb Tour)
    var cpuWins = 0
    var hardWins = 0
    var flawlessWins = 0
    var overtimeWins = 0
    var halloweenWins = 0
    var pins = 0
    var jumpPins = 0
    var escapes = 0
    var reversals = 0
    var winStreak = 0
    var bestStreak = 0
    var twoPlayerMatches = 0
}

@Observable
final class Profile {
    private(set) var data: ProfileData {
        didSet { save() }
    }

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "profile.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        data = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(ProfileData.self, from: $0) } ?? ProfileData()
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(data), forKey: Self.key)
    }

    /// Batches several changes into one save.
    func update(_ change: (inout ProfileData) -> Void) {
        var copy = data
        change(&copy)
        data = copy
    }

    // MARK: Items

    var coins: Int { data.coins }

    func owns(_ item: Accessory) -> Bool {
        item.unlock == .free || data.owned.contains(item.id)
    }

    var ownedCount: Int { Accessory.all.filter(owns).count }

    /// Spends coins on an item. Returns false if it isn't for coins or is too pricey.
    @discardableResult
    func buy(_ item: Accessory) -> Bool {
        guard case .coins(let price) = item.unlock, !owns(item), data.coins >= price else { return false }
        update {
            $0.coins -= price
            $0.owned.insert(item.id)
        }
        return true
    }

    // MARK: Thumb Tour

    func starMask(_ challenge: Challenge) -> Int { data.stars[challenge.id] ?? 0 }

    func stars(_ challenge: Challenge) -> Int { starMask(challenge).nonzeroBitCount }

    var totalStars: Int { data.stars.values.reduce(0) { $0 + $1.nonzeroBitCount } }

    /// The first challenge is open; each one after unlocks once the previous is won.
    func isOpen(_ challenge: Challenge) -> Bool {
        guard let previous = Challenge.all.first(where: { $0.id == challenge.id - 1 }) else { return true }
        return starMask(previous) & 1 != 0
    }

    var clearedChallenges: Int { Challenge.all.filter { starMask($0) & 1 != 0 }.count }
}
