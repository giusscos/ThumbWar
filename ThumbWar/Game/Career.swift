//
//  Career.swift
//  ThumbWar
//
//  Turns finished matches into progress: Thumb Tour stars and coins, lifetime
//  stats, achievements, Game Center reports and the toasts that announce them.
//

import Foundation
import Observation

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let coins: Int
}

struct StoryResult: Equatable {
    let challengeID: Int
    let won: Bool
    /// Stars met in this match (win, goal 1, goal 2).
    let earned: [Bool]
    /// Stars earned for the first time, which are the ones that pay.
    let newlyEarned: [Bool]
    let coins: Int
}

@MainActor
@Observable
final class Career {
    let profile: Profile
    let gameCenter: GameCenter
    private(set) var activeChallenge: Challenge?
    private(set) var storyResult: StoryResult?
    private(set) var toasts: [Toast] = []
    /// The Thumb Tour map is open.
    var showTour = false

    init(profile: Profile, gameCenter: GameCenter) {
        self.profile = profile
        self.gameCenter = gameCenter
    }

    /// Signs in to Game Center and catches it up with progress made offline.
    func connect() {
        gameCenter.authenticate { [weak self] in
            guard let self else { return }
            self.gameCenter.report(Achievement.all.filter { self.profile.data.achievements.contains($0.id) })
            self.submitLeaderboards()
        }
    }

    // MARK: Starting matches

    func play(_ challenge: Challenge, game: ThumbWarGame, settings: GameSettings) {
        activeChallenge = challenge
        storyResult = nil
        settings.rivalLoadout = challenge.loadout
        game.rivalName = challenge.rival
        game.start(mode: .vsCPU, rules: challenge.rules)
    }

    func playQuick(_ mode: ThumbWarGame.Mode, game: ThumbWarGame, settings: GameSettings) {
        leave(settings: settings)
        game.rivalName = nil
        game.start(mode: mode, length: settings.matchLength)
    }

    func leave(settings: GameSettings) {
        activeChallenge = nil
        storyResult = nil
        settings.rivalLoadout = nil
    }

    // MARK: Results

    func matchFinished(game: ThumbWarGame, winner: Side?, settings: GameSettings) {
        if game.mode == .twoPlayers {
            profile.update { $0.twoPlayerMatches += 1 }
        } else {
            let stats = game.stats
            let won = winner == .left
            let level = game.effectiveCPULevel
            let spooky = settings.loadout(.left).ids.compactMap(Accessory.with(id:)).contains { $0.theme == .halloween }
            profile.update { d in
                d.pins += stats.pins[0]
                d.jumpPins += stats.jumpPins[0]
                d.escapes += stats.escapes[0]
                d.reversals += stats.reversals[0]
                if won {
                    d.cpuWins += 1
                    d.winStreak += 1
                    d.bestStreak = max(d.bestStreak, d.winStreak)
                    if level == .hard { d.hardWins += 1 }
                    if level != .easy && game.scores[1] == 0 { d.flawlessWins += 1 }
                    if stats.overtimeScorer == .left { d.overtimeWins += 1 }
                    if spooky { d.halloweenWins += 1 }
                } else {
                    d.winStreak = 0
                }
            }
            if let challenge = activeChallenge {
                settle(challenge, won: won, game: game)
            }
        }
        checkAchievements()
        submitLeaderboards()
    }

    private func settle(_ challenge: Challenge, won: Bool, game: ThumbWarGame) {
        var earned = [won, false, false]
        if won {
            for (k, goal) in challenge.goals.prefix(2).enumerated() {
                earned[k + 1] = goal.isMet(by: game.stats, scores: game.scores)
            }
        }
        let oldMask = profile.starMask(challenge)
        var mask = oldMask
        var newly = [false, false, false]
        for k in 0..<3 where earned[k] && oldMask & (1 << k) == 0 {
            newly[k] = true
            mask |= 1 << k
        }
        let coins = newly.filter { $0 }.count * challenge.coinsPerStar
        profile.update {
            $0.stars[challenge.id] = mask
            $0.coins += coins
        }
        storyResult = StoryResult(challengeID: challenge.id, won: won, earned: earned, newlyEarned: newly, coins: coins)
    }

    /// Pays out any achievement whose goal is now met. Also called after purchases.
    func checkAchievements() {
        var unlocked: [Achievement] = []
        for achievement in Achievement.all
        where !profile.data.achievements.contains(achievement.id) && achievement.isEarned(profile.data) {
            profile.update {
                $0.achievements.insert(achievement.id)
                $0.coins += achievement.coins
            }
            unlocked.append(achievement)
            show(Toast(title: achievement.title, coins: achievement.coins))
        }
        gameCenter.report(unlocked)
    }

    private func submitLeaderboards() {
        gameCenter.submit(profile.totalStars, to: .stars)
        gameCenter.submit(profile.data.pins, to: .pins)
        gameCenter.submit(profile.data.bestStreak, to: .streak)
    }

    // MARK: Toasts

    private func show(_ toast: Toast) {
        toasts.append(toast)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3.2))
            self?.toasts.removeAll { $0.id == toast.id }
        }
    }
}
