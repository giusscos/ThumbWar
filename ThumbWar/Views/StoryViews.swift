//
//  StoryViews.swift
//  ThumbWar
//
//  The Thumb Tour: chapter map, challenge card and the star result screen.
//

import SwiftUI

struct TourView: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    @Environment(Career.self) private var career
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var selected: Challenge?

    var body: some View {
        let profile = career.profile
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            PuffyCard {
                VStack(spacing: 12) {
                    header(profile)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(Challenge.chapters) { chapter in
                                Text("Chapter \(chapter.id) · \(chapter.title)".uppercased())
                                    .font(.system(.footnote, design: .rounded, weight: .black))
                                    .foregroundStyle(PuffyPalette.ink.opacity(0.75))
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 12) {
                                    ForEach(Challenge.all.filter { $0.chapter == chapter.id }) { challenge in
                                        ChallengeNode(challenge: challenge, stars: profile.stars(challenge),
                                                      open: profile.isOpen(challenge)) {
                                            feedback.tap()
                                            selected = challenge
                                        }
                                    }
                                }
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

            if let selected {
                ChallengeCard(challenge: selected, mask: profile.starMask(selected), feedback: feedback,
                              onClose: { self.selected = nil },
                              onFight: {
                                  self.selected = nil
                                  career.showTour = false
                                  career.play(selected, game: game, settings: settings)
                              })
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(duration: 0.3, bounce: 0.3), value: selected?.id)
        .onAppear { AccessoryLibrary.shared.load(Challenge.all.flatMap(\.loadout.ids)) }
    }

    /// One row in landscape; title and Done over the stats on a tall screen.
    @ViewBuilder private func header(_ profile: Profile) -> some View {
        let title = PuffyText(text: "Thumb Tour", size: 32, color: .orange)
        let stats = HStack(spacing: 10) {
            StarPill(stars: profile.totalStars, total: Challenge.all.count * 3)
            CoinPill(coins: profile.coins)
        }
        let done = PuffyButton(title: "Done", color: .green, compact: true) {
            feedback.tap()
            career.showTour = false
        }
        .fixedSize()
        if verticalSizeClass == .compact {
            HStack(spacing: 10) { title; Spacer(minLength: 4); stats; done }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack { title; Spacer(); done }
                stats
            }
        }
    }
}

/// The rival's signature item, as a picture.
struct RivalBadge: View {
    let challenge: Challenge
    var size: CGFloat = 52

    var body: some View {
        let id = challenge.loadout.hat ?? challenge.loadout.face
        Group {
            if let item = Accessory.with(id: id), let image = UIImage(named: item.thumbnailName) {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Image(systemName: "hand.thumbsup.fill").font(.system(size: size * 0.5, weight: .black))
            }
        }
        .frame(width: size, height: size)
    }
}

private struct ChallengeNode: View {
    let challenge: Challenge
    let stars: Int
    let open: Bool
    let action: () -> Void

    var body: some View {
        let cleared = stars > 0
        let color: Color = !open ? Color(white: 0.82) : (cleared ? .orange : PuffyPalette.blue)
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack {
                    RivalBadge(challenge: challenge, size: 50)
                        .opacity(open ? 1 : 0.35)
                    if !open {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.3), radius: 0, y: 2)
                    }
                }
                Text("\(challenge.id)")
                    .font(.system(.headline, design: .rounded, weight: .black))
                HStack(spacing: 1) {
                    ForEach(0..<3, id: \.self) { k in StarIcon(filled: k < stars, size: 12) }
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PuffyButtonStyle(color: color, shape: RoundedRectangle(cornerRadius: 20, style: .continuous), depth: 5))
        .disabled(!open)
        .overlay(alignment: .topTrailing) {
            if challenge.isBoss {
                Text("BOSS")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(PuffyPalette.red.gradient, in: Capsule())
                    .overlay(Capsule().stroke(.white, lineWidth: 2))
                    .offset(x: 4, y: -6)
            }
        }
    }
}

private struct ChallengeCard: View {
    let challenge: Challenge
    let mask: Int
    let feedback: GameFeedback
    let onClose: () -> Void
    let onFight: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea().onTapGesture(perform: onClose)
            PuffyCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        RivalBadge(challenge: challenge, size: 78)
                            .background(Circle().fill(.white.opacity(0.7)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Challenge \(challenge.id)" + (challenge.isBoss ? " · BOSS" : ""))
                                .font(.system(.caption, design: .rounded, weight: .black))
                                .foregroundStyle(challenge.isBoss ? PuffyPalette.red : PuffyPalette.ink.opacity(0.6))
                            PuffyText(text: challenge.rival, size: 28, color: challenge.isBoss ? PuffyPalette.red : PuffyPalette.blue)
                            Text("“\(challenge.quote)”")
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .italic()
                                .foregroundStyle(PuffyPalette.ink.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 6)], alignment: .leading, spacing: 6) {
                        ForEach(challenge.ruleTags, id: \.self) { tag in
                            Text(tag)
                                .font(.system(.caption, design: .rounded, weight: .heavy))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 10).padding(.vertical, 5)
                                .frame(maxWidth: .infinity)
                                .background(Color.purple.gradient, in: Capsule())
                        }
                    }
                    VStack(spacing: 8) {
                        goalRow(0, "Win the match")
                        ForEach(Array(challenge.goals.prefix(2).enumerated()), id: \.offset) { k, goal in
                            goalRow(k + 1, goal.text)
                        }
                    }
                    HStack(spacing: 12) {
                        PuffyButton(title: "Back", color: Color(white: 0.7), compact: true) {
                            feedback.tap()
                            onClose()
                        }
                        Spacer()
                        PuffyButton(title: "Fight!", color: .orange) {
                            feedback.tap()
                            onFight()
                        }
                    }
                }
                .padding(18)
            }
            .frame(maxWidth: 440)
            .padding(16)
        }
    }

    private func goalRow(_ k: Int, _ text: String) -> some View {
        let done = mask & (1 << k) != 0
        return HStack(spacing: 10) {
            StarIcon(filled: done, size: 22)
            Text(text)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(PuffyPalette.ink)
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.green)
            } else {
                Text("+\(challenge.coinsPerStar)")
                    .font(.system(.subheadline, design: .rounded, weight: .black))
                    .foregroundStyle(PuffyPalette.ink)
                CoinIcon(size: 18)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// End of a Thumb Tour match: stars, coins, and where to go next.
struct StoryResultView: View {
    let result: StoryResult
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    @Environment(Career.self) private var career
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        let challenge = Challenge.all.first { $0.id == result.challengeID }!
        let mask = career.profile.starMask(challenge)
        let compact = verticalSizeClass == .compact
        VStack(spacing: compact ? 6 : 12) {
            PuffyPop(text: result.won ? "Victory!" : "Defeated!", size: compact ? 54 : 64,
                     color: result.won ? .orange : PuffyPalette.red)
            PuffyTag {
                Text(result.won ? "You beat \(challenge.rival)!" : "\(challenge.rival) wins this time.")
            }
            PuffyCard {
                HStack(alignment: .top, spacing: 10) {
                    starColumn(0, "Win", mask: mask)
                    ForEach(Array(challenge.goals.prefix(2).enumerated()), id: \.offset) { k, goal in
                        starColumn(k + 1, goal.text, mask: mask)
                    }
                }
                .padding(.horizontal, 12).padding(.vertical, compact ? 8 : 12)
            }
            .padding(.bottom, 8)
            if result.coins > 0 {
                HStack(spacing: 6) {
                    PuffyText(text: "+\(result.coins)", size: 30, color: .yellow)
                    CoinIcon(size: 30)
                }
            }
            HStack(spacing: 12) {
                PuffyButton(title: "Retry", color: PuffyPalette.blue, compact: true) {
                    feedback.tap()
                    career.play(challenge, game: game, settings: settings)
                }
                if result.won, let next = challenge.next {
                    PuffyButton(title: "Next", color: .orange, compact: true) {
                        feedback.tap()
                        career.play(next, game: game, settings: settings)
                    }
                }
                PuffyButton(title: "Tour", color: .purple, compact: true) {
                    feedback.tap()
                    game.backToMenu()
                    career.leave(settings: settings)
                    career.showTour = true
                }
            }
        }
        .padding(.horizontal, 12)
    }

    private func starColumn(_ k: Int, _ caption: String, mask: Int) -> some View {
        let now = result.earned[k]
        let ever = mask & (1 << k) != 0
        return VStack(spacing: 4) {
            StarIcon(filled: ever, size: 40)
                .scaleEffect(result.newlyEarned[k] ? 1.15 : 1)
                .overlay(alignment: .topTrailing) {
                    if result.newlyEarned[k] {
                        Text("NEW")
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(PuffyPalette.red, in: Capsule())
                            .offset(x: 10, y: -4)
                    }
                }
            Text(caption)
                .font(.system(.caption2, design: .rounded, weight: .heavy))
                .foregroundStyle(PuffyPalette.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 90)
                .opacity(now || ever ? 1 : 0.6)
        }
    }
}
