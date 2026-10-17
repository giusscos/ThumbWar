//
//  Achievements.swift
//  ThumbWar
//
//  Achievements pay coins once and are mirrored to Game Center. The Game Center
//  IDs must also be created in App Store Connect (see Docs/GameCenter.md).
//

import Foundation

struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let coins: Int
    let target: Int
    let progress: (ProfileData) -> Int

    var gameCenterID: String { "thumbwar.achievement.\(id)" }

    func isEarned(_ data: ProfileData) -> Bool { progress(data) >= target }

    static let all: [Achievement] = [
        Achievement(id: "first_win", title: "First Pin-Down", detail: "Beat the CPU once", coins: 25, target: 1) { $0.cpuWins },
        Achievement(id: "pins_25", title: "Pin Pal", detail: "Score 25 pins against the CPU", coins: 50, target: 25) { $0.pins },
        Achievement(id: "pins_100", title: "Pin Pro", detail: "Score 100 pins against the CPU", coins: 150, target: 100) { $0.pins },
        Achievement(id: "pins_300", title: "Pin Legend", detail: "Score 300 pins against the CPU", coins: 300, target: 300) { $0.pins },
        Achievement(id: "jump_1", title: "Leap of Thumb", detail: "Pin with a jumping slam", coins: 50, target: 1) { $0.jumpPins },
        Achievement(id: "jump_20", title: "Frequent Flyer", detail: "Score 20 jumping pins", coins: 150, target: 20) { $0.jumpPins },
        Achievement(id: "escape_10", title: "Slippery Thumb", detail: "Escape 10 pins", coins: 100, target: 10) { $0.escapes },
        Achievement(id: "reversal_1", title: "Hook, Line & Sinker", detail: "Flip a pin from a hook", coins: 100, target: 1) { $0.reversals },
        Achievement(id: "flawless_1", title: "Untouchable", detail: "Beat a Normal or Hard CPU without being pinned", coins: 100, target: 1) { $0.flawlessWins },
        Achievement(id: "hard_1", title: "Thumb Master", detail: "Beat a Hard CPU", coins: 100, target: 1) { $0.hardWins },
        Achievement(id: "streak_5", title: "On Fire", detail: "Beat the CPU 5 times in a row", coins: 150, target: 5) { $0.bestStreak },
        Achievement(id: "overtime_1", title: "Buzzer Beater", detail: "Win with a pin in overtime", coins: 75, target: 1) { $0.overtimeWins },
        Achievement(id: "halloween_1", title: "Trick or Treat", detail: "Win wearing a Halloween item", coins: 50, target: 1) { $0.halloweenWins },
        Achievement(id: "friends_10", title: "Best Thumbs Forever", detail: "Play 10 two-player matches", coins: 50, target: 10) { $0.twoPlayerMatches },
        Achievement(id: "collector_10", title: "Dress to Impress", detail: "Own 10 items", coins: 100, target: 10) { data in
            Accessory.all.filter { $0.unlock == .free || data.owned.contains($0.id) }.count
        },
        Achievement(id: "tour_5", title: "Backyard Champ", detail: "Beat Sheriff Sam", coins: 100, target: 1) { $0.cleared(5) },
        Achievement(id: "tour_10", title: "City Slicker", detail: "Beat Merlin Thumb", coins: 150, target: 1) { $0.cleared(10) },
        Achievement(id: "tour_15", title: "Captain of the Seas", detail: "Beat Unicorn Uma", coins: 200, target: 1) { $0.cleared(15) },
        Achievement(id: "tour_20", title: "Thumb Royalty", detail: "Beat King Thumbert", coins: 300, target: 1) { $0.cleared(20) },
        Achievement(id: "stars_60", title: "Superstar", detail: "Earn all 60 Thumb Tour stars", coins: 100, target: 60) { data in
            data.stars.values.reduce(0) { $0 + $1.nonzeroBitCount }
        },
    ]
}

extension ProfileData {
    func cleared(_ challengeID: Int) -> Int { (stars[challengeID] ?? 0) & 1 }
}

enum Leaderboard: String, CaseIterable {
    case stars = "thumbwar.leaderboard.stars"
    case pins = "thumbwar.leaderboard.pins"
    case streak = "thumbwar.leaderboard.streak"

    var title: String {
        switch self {
        case .stars: "Thumb Tour Stars"
        case .pins: "Lifetime Pins"
        case .streak: "Best Win Streak"
        }
    }
}
