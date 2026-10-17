//
//  Challenges.swift
//  ThumbWar
//
//  The Thumb Tour: 20 rival thumbs in four chapters, a boss closing each one.
//  Winning earns the first star; each goal met in a win earns another.
//  Coins are paid once per star, the first time it's earned.
//

import Foundation

enum Goal: Equatable {
    /// Win without the rival scoring a pin.
    case flawless
    /// Win within this much fighting time (countdowns and pauses don't count).
    case within(seconds: Int)
    /// Score a pin that started with a jumping slam.
    case jumpPin
    /// Break free from a rival's pin.
    case escape
    /// Win by at least this many pins.
    case margin(Int)
    /// Keep your stamina above the "tired" line the whole match.
    case neverTired

    var text: String {
        switch self {
        case .flawless: "Don't get pinned"
        case .within(let s): "Win within \(s) s"
        case .jumpPin: "Pin with a jumping slam"
        case .escape: "Escape a pin"
        case .margin(let n): "Win by \(n)+ pins"
        case .neverTired: "Never get tired"
        }
    }

    /// `you` is always the left thumb in the Thumb Tour.
    func isMet(by stats: MatchStats, scores: [Int]) -> Bool {
        switch self {
        case .flawless: scores[1] == 0
        case .within(let s): stats.fightTime <= Float(s)
        case .jumpPin: stats.jumpPins[0] > 0
        case .escape: stats.escapes[0] > 0
        case .margin(let n): scores[0] - scores[1] >= n
        case .neverTired: stats.lowestStamina[0] >= Stamina.tired
        }
    }
}

struct Chapter: Identifiable {
    let id: Int
    let title: String
}

struct Challenge: Identifiable {
    let id: Int
    let rival: String
    let quote: String
    let loadout: Loadout
    let rules: MatchRules
    /// Goals for the second and third star.
    let goals: [Goal]

    var chapter: Int { (id - 1) / 5 + 1 }
    var isBoss: Bool { id % 5 == 0 }
    /// Later challenges pay more per star.
    var coinsPerStar: Int { 30 + 6 * id }

    /// Short labels for what makes this fight different.
    var ruleTags: [String] {
        var tags = [(rules.cpuLevel ?? .normal).title + " CPU"]
        if let p = rules.pointsToWin { tags.append(p == 1 ? "First pin wins" : "First to \(p)") }
        if let s = rules.seconds { tags.append("\(Int(s)) s clock") }
        if rules.pinSeconds < Arena.pinDuration { tags.append("Quick pins") }
        if rules.agility[1] > 1 { tags.append("Speedy rival") }
        if rules.regen[1] > 1 { tags.append("Tireless rival") }
        if rules.regen[0] < 1 { tags.append("You tire faster") }
        return tags
    }

    static let chapters = [
        Chapter(id: 1, title: "Backyard Brawl"),
        Chapter(id: 2, title: "City Circuit"),
        Chapter(id: 3, title: "High Seas"),
        Chapter(id: 4, title: "Royal Cup"),
    ]

    static let all: [Challenge] = [
        // Chapter 1: Backyard Brawl
        Challenge(id: 1, rival: "Rookie Rick", quote: "First time? Me too!",
                  loadout: Loadout(hat: "cap"),
                  rules: MatchRules(pointsToWin: 1, cpuLevel: .easy),
                  goals: [.within(seconds: 30), .neverTired]),
        Challenge(id: 2, rival: "Party Pam", quote: "Every pin is a party!",
                  loadout: Loadout(hat: "party", face: "heart"),
                  rules: MatchRules(pointsToWin: 2, cpuLevel: .easy),
                  goals: [.flawless, .within(seconds: 45)]),
        Challenge(id: 3, rival: "Beanie Ben", quote: "I never get cold feet. Or cold thumbs.",
                  loadout: Loadout(hat: "beanie", face: "glasses"),
                  rules: MatchRules(pointsToWin: 2, cpuLevel: .easy, regen: [1, 1.3]),
                  goals: [.jumpPin, .flawless]),
        Challenge(id: 4, rival: "Coco the Clown", quote: "Honk honk! You're going down!",
                  loadout: Loadout(hat: "propeller", face: "clown"),
                  rules: MatchRules(pointsToWin: 2, cpuLevel: .normal),
                  goals: [.escape, .margin(2)]),
        Challenge(id: 5, rival: "Sheriff Sam", quote: "This backyard ain't big enough for two thumbs.",
                  loadout: Loadout(hat: "cowboy", face: "mustache"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .normal, agility: [1, 1.1]),
                  goals: [.flawless, .jumpPin]),

        // Chapter 2: City Circuit
        Challenge(id: 6, rival: "DJ Dot", quote: "Keep up with the beat!",
                  loadout: Loadout(hat: "headphones", face: "shades"),
                  rules: MatchRules(pointsToWin: 2, seconds: 45, cpuLevel: .normal),
                  goals: [.within(seconds: 30), .neverTired]),
        Challenge(id: 7, rival: "Chef Remy", quote: "I'll have you pinned before the soup boils.",
                  loadout: Loadout(hat: "chef", face: "mustache"),
                  rules: MatchRules(pointsToWin: 3, pinSeconds: 2.5, cpuLevel: .normal),
                  goals: [.margin(2), .jumpPin]),
        Challenge(id: 8, rival: "Bunny Bo", quote: "Hop hop, too fast for you!",
                  loadout: Loadout(hat: "bunny", face: "heart"),
                  rules: MatchRules(pointsToWin: 2, cpuLevel: .normal, agility: [1, 1.25]),
                  goals: [.flawless, .escape]),
        Challenge(id: 9, rival: "Professor Pip", quote: "I've calculated your every move.",
                  loadout: Loadout(hat: "beanie", face: "monocle"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .normal, regen: [0.8, 1]),
                  goals: [.neverTired, .within(seconds: 60)]),
        Challenge(id: 10, rival: "Merlin Thumb", quote: "Abraca-PIN-bra!",
                  loadout: Loadout(hat: "wizard", face: "glasses"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .hard),
                  goals: [.flawless, .within(seconds: 70)]),

        // Chapter 3: High Seas
        Challenge(id: 11, rival: "Viking Vik", quote: "Thumbs of the north never rest!",
                  loadout: Loadout(hat: "viking", face: "mustache"),
                  rules: MatchRules(pointsToWin: 2, cpuLevel: .hard, regen: [1, 1.2]),
                  goals: [.escape, .jumpPin]),
        Challenge(id: 12, rival: "Captain Thumbbeard", quote: "Arr, walk the plank, landlubber!",
                  loadout: Loadout(hat: "pirate", face: "eyepatch"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .hard),
                  goals: [.margin(2), .neverTired]),
        Challenge(id: 13, rival: "Sir Monty", quote: "A gentleman pins quickly.",
                  loadout: Loadout(hat: "tophat", face: "monocle"),
                  rules: MatchRules(pointsToWin: 2, pinSeconds: 2, cpuLevel: .hard),
                  goals: [.flawless, .jumpPin]),
        Challenge(id: 14, rival: "Mummy Max", quote: "I've been waiting 3000 years for this.",
                  loadout: Loadout(hat: "mummy"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .hard, regen: [1, 1.4]),
                  goals: [.escape, .within(seconds: 70)]),
        Challenge(id: 15, rival: "Unicorn Uma", quote: "Magic AND speed. Good luck!",
                  loadout: Loadout(hat: "unicorn", face: "heart"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .hard, agility: [1, 1.25]),
                  goals: [.flawless, .jumpPin]),

        // Chapter 4: Royal Cup
        Challenge(id: 16, rival: "Witchy Wanda", quote: "Double, double, thumb in trouble!",
                  loadout: Loadout(hat: "witch", face: "witchnose"),
                  rules: MatchRules(pointsToWin: 3, seconds: 60, cpuLevel: .hard),
                  goals: [.margin(2), .neverTired]),
        Challenge(id: 17, rival: "Count Fangula", quote: "I vant to pin your thumb!",
                  loadout: Loadout(hat: "spider", face: "fangs"),
                  rules: MatchRules(pointsToWin: 3, pinSeconds: 2.5, cpuLevel: .hard, regen: [1, 1.3]),
                  goals: [.flawless, .escape]),
        Challenge(id: 18, rival: "Frankie", quote: "FRANKIE... PIN... THUMB!",
                  loadout: Loadout(hat: "frankenstein"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .hard, regen: [1, 1.3], agility: [1, 1.15]),
                  goals: [.jumpPin, .within(seconds: 60)]),
        Challenge(id: 19, rival: "Halo Hana", quote: "Heavenly fast, devilishly strong.",
                  loadout: Loadout(hat: "halo", face: "shades"),
                  rules: MatchRules(pointsToWin: 3, cpuLevel: .hard, regen: [0.85, 1], agility: [1, 1.3]),
                  goals: [.flawless, .neverTired]),
        Challenge(id: 20, rival: "King Thumbert", quote: "Kneel before the thumb of thumbs!",
                  loadout: Loadout(hat: "crown", face: "mustache"),
                  rules: MatchRules(pointsToWin: 3, pinSeconds: 2.5, cpuLevel: .hard, regen: [1, 1.4], agility: [1, 1.35]),
                  goals: [.flawless, .jumpPin]),
    ]

    var next: Challenge? { Challenge.all.first { $0.id == id + 1 } }
}
