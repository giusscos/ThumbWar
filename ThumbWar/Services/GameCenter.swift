//
//  GameCenter.swift
//  ThumbWar
//
//  Sign-in, achievements and leaderboards. Everything here is best effort: the
//  game keeps its own progress, so it works the same when Game Center is off.
//

import GameKit
import Observation
import UIKit

@MainActor
@Observable
final class GameCenter {
    private(set) var isAuthenticated = false

    func authenticate(onReady: @escaping @MainActor () -> Void) {
        GKLocalPlayer.local.authenticateHandler = { @Sendable viewController, _ in
            Task { @MainActor [weak self] in
                if let viewController {
                    Self.topViewController()?.present(viewController, animated: true)
                }
                let signedIn = GKLocalPlayer.local.isAuthenticated
                self?.isAuthenticated = signedIn
                if signedIn { onReady() }
            }
        }
    }

    func report(_ achievements: [Achievement]) {
        guard isAuthenticated, !achievements.isEmpty else { return }
        let ids = achievements.map(\.gameCenterID)
        Task {
            let list = ids.map { id in
                let achievement = GKAchievement(identifier: id)
                achievement.percentComplete = 100
                achievement.showsCompletionBanner = false  // the game shows its own toast
                return achievement
            }
            try? await GKAchievement.report(list)
        }
    }

    func submit(_ value: Int, to board: Leaderboard) {
        guard isAuthenticated, value > 0 else { return }
        Task {
            try? await GKLeaderboard.submitScore(value, context: 0, player: GKLocalPlayer.local,
                                                 leaderboardIDs: [board.rawValue])
        }
    }

    func showAchievements() {
        GKAccessPoint.shared.trigger(state: .achievements) {}
    }

    func showLeaderboard(_ board: Leaderboard) {
        GKAccessPoint.shared.trigger(leaderboardID: board.rawValue, playerScope: .global, timeScope: .allTime) {}
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
