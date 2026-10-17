//
//  TrophiesView.swift
//  ThumbWar
//
//  Achievements with progress and rewards, plus Game Center leaderboards.
//

import SwiftUI

struct TrophiesView: View {
    let feedback: GameFeedback
    let onDone: () -> Void
    @Environment(Career.self) private var career
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let data = career.profile.data
        let earned = Achievement.all.filter { data.achievements.contains($0.id) }.count
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            PuffyCard {
                VStack(spacing: 12) {
                    header(earned: earned)
                    leaderboards
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 10)], spacing: 10) {
                            ForEach(Achievement.all) { achievement in
                                AchievementRow(achievement: achievement, data: data)
                            }
                        }
                        .padding(4)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollEdgeFade()
                }
                .padding(16)
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder private func header(earned: Int) -> some View {
        let title = HStack(spacing: 8) {
            PuffyText(text: "Trophies", size: 32, color: .yellow)
            Text("\(earned)/\(Achievement.all.count)")
                .font(.system(.headline, design: .rounded, weight: .black))
                .foregroundStyle(PuffyPalette.ink.opacity(0.7))
        }
        let done = PuffyButton(title: "Done", color: .green, compact: true) {
            feedback.tap()
            onDone()
        }
        .fixedSize()
        if verticalSizeClass == .compact {
            HStack(spacing: 10) { title; Spacer(minLength: 4); CoinPill(coins: career.profile.coins); done }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack { title; Spacer(); done }
                CoinPill(coins: career.profile.coins)
            }
        }
    }

    @ViewBuilder private var leaderboards: some View {
        if career.gameCenter.isAuthenticated {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { boardButtons }
                ScrollView(.horizontal, showsIndicators: false) { HStack(spacing: 8) { boardButtons }.padding(.horizontal, 2) }
                    .scrollEdgeFade(.horizontal, length: 14)
            }
        } else {
            Label("Sign in to Game Center in the Settings app to see leaderboards.", systemImage: "gamecontroller.fill")
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .foregroundStyle(PuffyPalette.ink.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder private var boardButtons: some View {
        ForEach(Leaderboard.allCases, id: \.self) { board in
            Button {
                feedback.tap()
                career.gameCenter.showLeaderboard(board)
            } label: {
                Label(board.title, systemImage: "list.number")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .lineLimit(1)
                    .padding(.horizontal, 12).padding(.vertical, 9)
            }
            .buttonStyle(.puffy(PuffyPalette.blue))
            .fixedSize()
        }
        Button {
            feedback.tap()
            career.gameCenter.showAchievements()
        } label: {
            Label("Game Center", systemImage: "gamecontroller.fill")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .lineLimit(1)
                .padding(.horizontal, 12).padding(.vertical, 9)
        }
        .buttonStyle(.puffy(.purple))
        .fixedSize()
    }
}

private struct AchievementRow: View {
    let achievement: Achievement
    let data: ProfileData

    var body: some View {
        let done = data.achievements.contains(achievement.id)
        let value = min(achievement.progress(data), achievement.target)
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(done ? Color.yellow : Color.white)
                .shadow(color: done ? .orange : .clear, radius: 0, y: 2)
                .frame(width: 46, height: 46)
                .background(Circle().fill(done ? Color.orange : Color(white: 0.78)))
            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(PuffyPalette.ink)
                Text(achievement.detail)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(PuffyPalette.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                if achievement.target > 1 && !done {
                    Capsule()
                        .fill(.black.opacity(0.12))
                        .frame(height: 8)
                        .overlay(alignment: .leading) {
                            GeometryReader { geo in
                                Capsule().fill(Color.orange)
                                    .frame(width: geo.size.width * CGFloat(value) / CGFloat(achievement.target))
                            }
                        }
                    Text("\(value)/\(achievement.target)")
                        .font(.system(.caption2, design: .rounded, weight: .heavy))
                        .foregroundStyle(PuffyPalette.ink.opacity(0.6))
                }
            }
            Spacer(minLength: 4)
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.green)
            } else if achievement.coins > 0 {
                HStack(spacing: 3) {
                    Text("+\(achievement.coins)")
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                        .foregroundStyle(PuffyPalette.ink)
                    CoinIcon(size: 18)
                }
            }
        }
        .padding(12)
        .background(.white.opacity(done ? 0.95 : 0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
