//
//  HUD.swift
//  ThumbWar
//
//  Overlays for each layout, plus the menu, pause and result screens.
//  `viewer` is the player a piece of HUD faces; nil means a shared screen.
//

import SwiftUI

extension ThumbWarGame {
    func label(_ side: Side, viewer: Side? = nil) -> String {
        if mode == .vsCPU { return side == .left ? "You" : (rivalName ?? "CPU") }
        if let viewer { return side == viewer ? "You" : side.name }
        return side.name
    }

    var isMashing: Bool {
        if case .pinned = stage { true } else { false }
    }
}

/// The slam button wired to one player: tap to slam, hold to hook, mash during pins.
struct PlayerSlamButton: View {
    let game: ThumbWarGame
    let side: Side
    var size: CGFloat = 96

    var body: some View {
        let title = game.isMashing ? "MASH!" : (game.thumb(side).isHooking ? "HOOK" : "SLAM")
        SlamButton(side: side, title: title, enabled: game.canSlam(side) || game.thumb(side).phase == .down,
                   pulse: game.isMashing, size: size,
                   action: { game.slamPressed(side) },
                   release: { game.slamReleased(side) })
    }
}

// MARK: - Layout HUDs

struct LandscapeHUD: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback

    private var buttons: Bool { settings.slamControl == .button && game.isPlaying }

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    ScorePill(side: .left, score: game.scores[0], label: game.label(.left))
                    Spacer()
                    ClockAndPause(game: game, feedback: feedback)
                    Spacer()
                    ScorePill(side: .right, score: game.scores[1], label: game.label(.right))
                }
                Spacer()
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        if buttons { slam(.left) }
                        StaminaBar(value: game.stamina[0], side: .left)
                    }
                    Spacer()
                    HintPill(game: game, settings: settings)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        if buttons && game.mode == .twoPlayers { slam(.right) }
                        StaminaBar(value: game.stamina[1], side: .right)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)

            StageBanner(game: game, settings: settings, feedback: feedback, viewer: nil)
        }
    }

    private func slam(_ side: Side) -> some View {
        PlayerSlamButton(game: game, side: side)
    }
}

/// Portrait against the CPU: everything the player needs sits at the bottom.
struct PortraitHUD: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    ScorePill(side: .left, score: game.scores[0], label: game.label(.left))
                    Spacer()
                    ClockAndPause(game: game, feedback: feedback)
                    Spacer()
                    ScorePill(side: .right, score: game.scores[1], label: game.label(.right))
                }
                Spacer()
                HintPill(game: game, settings: settings)
                HStack(alignment: .bottom) {
                    StaminaBar(value: game.stamina[0], side: .left)
                    Spacer()
                    if settings.slamControl == .button && game.isPlaying {
                        PlayerSlamButton(game: game, side: .left, size: 104)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            StageBanner(game: game, settings: settings, feedback: feedback, viewer: .left)
        }
    }
}

/// One half of the portrait split screen, oriented for `viewer`.
struct PlayerHalfHUD: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    let viewer: Side

    var body: some View {
        ZStack {
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    // Scores live down by the player, keeping the seam free for the clock.
                    // Stamina sits above them, clear of the screen edge and the Dynamic Island.
                    VStack(alignment: .leading, spacing: 8) {
                        StaminaBar(value: game.stamina[viewer.rawValue], side: .left, tint: viewer)
                        HStack(spacing: 8) {
                            ScorePill(side: viewer, score: game.scores[viewer.rawValue], label: game.label(viewer, viewer: viewer))
                            ScorePill(side: viewer.opponent, score: game.scores[viewer.opponent.rawValue],
                                      label: game.label(viewer.opponent, viewer: viewer))
                        }
                    }
                    Spacer()
                    if settings.slamControl == .button && game.isPlaying {
                        PlayerSlamButton(game: game, side: viewer, size: 92)
                    }
                }
            }
            StageBanner(game: game, settings: settings, feedback: feedback, viewer: viewer, compact: true)
        }
    }
}

// MARK: - Banners

/// The big center messages: countdown, pin, point and match result.
struct StageBanner: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    let viewer: Side?
    var compact = false
    @Environment(Career.self) private var career

    private var scale: CGFloat { compact ? 0.75 : 1 }

    var body: some View {
        switch game.stage {
        case .chant(let beat):
            fittingPop(ThumbWarGame.chantWords[beat], size: (beat < 3 ? 130 : 88) * scale, color: chantColor(beat))
                .id(beat)
                .allowsHitTesting(false)
        case .pinned(let pinner):
            pin(pinner).allowsHitTesting(false)
        case .roundOver(let winner):
            fittingPop("+1 \(game.label(winner, viewer: viewer))!", size: 60 * scale, color: PuffyPalette.team(winner))
                .allowsHitTesting(false)
        case .matchOver(let winner):
            if game.mode == .vsCPU, let story = career.storyResult {
                StoryResultView(result: story, game: game, settings: settings, feedback: feedback)
            } else {
                result(winner)
            }
        case .menu, .fight:
            EmptyView()
        }
    }

    /// Big puffy text that shrinks, then wraps, rather than spilling off narrow screens.
    private func fittingPop(_ text: String, size: CGFloat, color: Color) -> some View {
        ViewThatFits(in: .horizontal) {
            PuffyPop(text: text, size: size, color: color)
            PuffyPop(text: text, size: size * 0.75, color: color)
            PuffyPop(text: text.replacingOccurrences(of: " ", with: "\n"), size: size * 0.75, color: color)
        }
        .padding(.horizontal, 16)
    }

    private func chantColor(_ beat: Int) -> Color {
        [PuffyPalette.blue, .yellow, PuffyPalette.red, .orange][beat]
    }

    private func pin(_ pinner: Side) -> some View {
        let pinned = pinner.opponent
        let count = min(3, Int(game.pinProgress * 3) + 1)
        let mash = settings.slamControl == .button
        let flip = game.pinIsReversible
        let escapeVerb = flip ? "flip them" : "escape"
        let line: String = switch viewer {
        case pinned?: mash ? "MASH to \(escapeVerb)!" : "Wiggle to \(escapeVerb)!"
        case pinner?: mash ? (flip ? "It's a hook! MASH to hold!" : "MASH to hold!") : "Hold it!"
        default: mash ? "\(game.label(pinned)): MASH to \(escapeVerb)! · \(game.label(pinner)): MASH to hold!"
                      : "\(game.label(pinned)), wiggle to \(escapeVerb)!"
        }
        return VStack(spacing: 6) {
            PuffyPop(text: "\(count)", size: 72 * scale, color: PuffyPalette.team(pinner))
                .id(count)
            PuffyTag(compact: compact) { Text(line) }
            TugBar(progress: game.escapeProgress, escaper: pinned)
                .frame(width: 200)
        }
        .padding(.top, compact ? 40 : 64)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func result(_ winner: Side?) -> some View {
        // Personal results read as win/lose; a shared screen names the winner.
        let me: Side? = game.mode == .vsCPU ? .left : viewer
        let (title, color): (String, Color) = {
            guard let winner else { return ("Draw!", .purple) }
            if let me { return winner == me ? ("You win!", .orange) : ("You lose!", PuffyPalette.red) }
            return ("\(winner.name) wins!", PuffyPalette.team(winner))
        }()
        return VStack(spacing: 12) {
            fittingPop(title, size: 68 * scale, color: color)
            HStack(spacing: 10) {
                ScorePill(side: .left, score: game.scores[0], label: game.label(.left, viewer: viewer), large: !compact)
                PuffyText(text: "–", size: compact ? 26 : 34, color: .orange)
                ScorePill(side: .right, score: game.scores[1], label: game.label(.right, viewer: viewer), large: !compact)
            }
            HStack(spacing: 14) {
                PuffyButton(title: "Rematch", color: PuffyPalette.blue, compact: compact) {
                    feedback.tap()
                    game.rematch()
                }
                PuffyButton(title: "Menu", color: .orange, compact: compact) {
                    feedback.tap()
                    game.backToMenu()
                    career.leave(settings: settings)
                }
            }
        }
    }
}

// MARK: - Screens

struct MenuView: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    @Binding var showSettings: Bool
    @Binding var showLocker: Bool
    @Binding var showTrophies: Bool
    @Environment(Career.self) private var career
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    // Landscape shares the top row with the corner buttons, so it's a bit smaller.
                    PuffyText(text: "THUMBEST WAR", size: verticalSizeClass == .compact ? 50 : 60, color: .orange)
                    PuffyText(text: "THUMBEST WAR", size: 44, color: .orange)
                    VStack(spacing: 0) {
                        PuffyText(text: "THUMBEST", size: 44, color: .orange)
                        PuffyText(text: "WAR", size: 44, color: .orange)
                    }
                }
                // Clear of the corner buttons in portrait; landscape keeps it off the thumbs.
                .padding(.top, verticalSizeClass == .compact ? 8 : 96)
                Spacer()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { tourButton; quickButton; twoPlayerButton }
                    VStack(spacing: 12) {
                        tourButton
                        HStack(spacing: 12) { quickButton; twoPlayerButton }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            HStack(spacing: 10) {
                Button {
                    feedback.tap()
                    showLocker = true
                } label: {
                    Label("Locker", systemImage: "tshirt.fill")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .padding(.horizontal, 14)
                        .frame(height: 44)
                }
                .buttonStyle(.puffy(.pink))
                RoundIconButton(systemName: "trophy.fill", color: .yellow) {
                    feedback.tap()
                    showTrophies = true
                }
                Spacer()
                CoinPill(coins: career.profile.coins)
                RoundIconButton(systemName: "gearshape.fill", color: .purple) {
                    feedback.tap()
                    showSettings = true
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }

    private var tourButton: some View {
        Button {
            feedback.tap()
            career.showTour = true
        } label: {
            HStack(spacing: 8) {
                Group {
                    Image(systemName: "map.fill")
                    Text("Thumb Tour")
                }
                .shadow(color: .black.opacity(0.18), radius: 0, y: 1.5)
                HStack(spacing: 3) {
                    StarIcon(filled: true, size: 14)
                    Text("\(career.profile.totalStars)")
                        .monospacedDigit()
                        .foregroundStyle(PuffyPalette.ink)
                }
                .font(.system(.subheadline, design: .rounded, weight: .black))
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(PuffySurface(shape: Capsule(), color: .white, depth: 3))
                .padding(.bottom, 3)
            }
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
        }
        .buttonStyle(.puffy(.orange))
    }

    private var quickButton: some View {
        PuffyButton(title: "Quick Play", color: PuffyPalette.blue) {
            feedback.tap()
            career.playQuick(.vsCPU, game: game, settings: settings)
        }
    }

    private var twoPlayerButton: some View {
        PuffyButton(title: "2 Players", color: PuffyPalette.red) {
            feedback.tap()
            career.playQuick(.twoPlayers, game: game, settings: settings)
        }
    }
}

struct PauseMenu: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    @Binding var showSettings: Bool
    @Environment(Career.self) private var career

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                PuffyText(text: "Paused", size: 56, color: .orange)
                if let challenge = career.activeChallenge {
                    // Remind the player what the stars are for; stars already earned show filled.
                    let mask = career.profile.starMask(challenge)
                    let goals = ["Win the match"] + challenge.goals.prefix(2).map(\.text)
                    PuffyCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("vs \(challenge.rival)".uppercased())
                                .font(.system(.footnote, design: .rounded, weight: .black))
                                .foregroundStyle(PuffyPalette.ink.opacity(0.7))
                            ForEach(Array(goals.enumerated()), id: \.offset) { k, goal in
                                HStack(spacing: 8) {
                                    StarIcon(filled: mask & (1 << k) != 0, size: 18)
                                    Text(goal)
                                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                        .foregroundStyle(PuffyPalette.ink)
                                }
                            }
                        }
                        .padding(.horizontal, 18).padding(.vertical, 14)
                    }
                    .frame(maxWidth: 360)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons }
                    VStack(spacing: 10) { buttons }
                }
            }
            .padding()
        }
    }

    @ViewBuilder private var buttons: some View {
        PuffyButton(title: "Resume", color: .green) {
            feedback.tap()
            game.isPaused = false
        }
        PuffyButton(title: "Restart", color: PuffyPalette.blue) {
            feedback.tap()
            game.rematch()
        }
        PuffyButton(title: "Settings", color: .purple) {
            feedback.tap()
            showSettings = true
        }
        PuffyButton(title: "Quit", color: PuffyPalette.red) {
            feedback.tap()
            game.backToMenu()
            career.leave(settings: settings)
        }
    }
}

// MARK: - Small pieces

struct ClockAndPause: View {
    let game: ThumbWarGame
    let feedback: GameFeedback

    var body: some View {
        if game.isPlaying {
            HStack(spacing: 10) {
                if let seconds = game.secondsLeft {
                    TimerPill(seconds: seconds, overtime: game.isOvertime)
                }
                RoundIconButton(systemName: "pause.fill") {
                    feedback.tap()
                    game.isPaused = true
                }
            }
        }
    }
}

struct HintPill: View {
    let game: ThumbWarGame
    let settings: GameSettings

    var body: some View {
        if game.stage == .fight {
            PuffyTag(compact: true) {
                Label(settings.slamControl == .lift ? "Drag to move · Lift to slam" : "Drag · Tap SLAM · Hold to hook",
                      systemImage: "hand.draw.fill")
                    .labelStyle(HintLabelStyle())
            }
            .allowsHitTesting(false)
        }
    }
}

/// Icon tinted orange, text in ink, kept tight.
private struct HintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.foregroundStyle(.orange)
            configuration.title
        }
    }
}

struct ScorePill: View {
    let side: Side
    let score: Int
    let label: String
    var large = false

    var body: some View {
        let depth: CGFloat = large ? 6 : 4
        HStack(spacing: 8) {
            Text(label).font(.system(large ? .title3 : .headline, design: .rounded, weight: .heavy))
            Text("\(score)")
                .font(.system(large ? .title : .title3, design: .rounded, weight: .black))
                .contentTransition(.numericText())
                .animation(.spring, value: score)
        }
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.18), radius: 0, y: 1.5)
        .padding(.horizontal, large ? 18 : 14).padding(.vertical, large ? 9 : 7)
        .background(PuffySurface(shape: Capsule(), color: PuffyPalette.team(side), depth: depth))
        .padding(.bottom, depth)
        .allowsHitTesting(false)
    }
}

struct TimerPill: View {
    let seconds: Int
    let overtime: Bool

    var body: some View {
        let urgent = overtime || seconds <= 5
        Text(overtime ? "OVERTIME" : String(format: "%d:%02d", seconds / 60, seconds % 60))
            .font(.system(.title3, design: .rounded, weight: .black))
            .monospacedDigit()
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(PuffySurface(shape: Capsule(), color: urgent ? .red : .gray, depth: 4))
            .padding(.bottom, 4)
            .scaleEffect(urgent ? 1.08 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.6), value: seconds)
            .allowsHitTesting(false)
    }
}

/// Pin tug-of-war: starts in the middle. The pinned player's color pushes
/// right; past the middle when the count ends (or all the way) means escape.
struct TugBar: View {
    let progress: Float
    let escaper: Side

    var body: some View {
        let depth: CGFloat = 4
        Capsule()
            .fill(gloss(PuffyPalette.team(escaper.opponent)))
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(gloss(PuffyPalette.team(escaper)))
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))))
                        .animation(.spring(duration: 0.15), value: progress)
                }
            }
            .clipShape(Capsule())
            .overlay { Capsule().fill(.white).frame(width: 4, height: 14) }
            .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
            .frame(height: 20)
            .background(Capsule().fill(PuffyPalette.ink.opacity(0.45)).offset(y: depth))
            .padding(.bottom, depth)
    }

    private func gloss(_ color: Color) -> LinearGradient {
        LinearGradient(colors: [color.mix(with: .white, by: 0.3), color], startPoint: .top, endPoint: .bottom)
    }
}

/// A white puffy pill: bolt, label and bar, readable over any part of the arena.
struct StaminaBar: View {
    let value: Float
    /// Which edge the bar grows from; the bolt sits on that side too.
    let side: Side
    /// Bar color; defaults to `side`.
    var tint: Side?

    private let barWidth: CGFloat = 96

    var body: some View {
        let tired = value < Stamina.tired
        let leading = side == .left
        let color = PuffyPalette.team(tint ?? side)
        HStack(spacing: 7) {
            if leading { bolt(tired: tired) }
            VStack(alignment: leading ? .leading : .trailing, spacing: 3) {
                Text(tired ? "TIRED!" : "STAMINA")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(tired ? PuffyPalette.red : PuffyPalette.ink.opacity(0.8))
                bar(color: color, tired: tired, leading: leading)
            }
            if !leading { bolt(tired: tired) }
        }
        .padding(.leading, leading ? 8 : 14).padding(.trailing, leading ? 14 : 8)
        .padding(.vertical, 6)
        .background(PuffySurface(shape: Capsule(), color: .white, depth: 4))
        .padding(.bottom, 4)
        .scaleEffect(tired ? 1.06 : 1)
        .animation(.spring(duration: 0.3, bounce: 0.6), value: tired)
        .allowsHitTesting(false)
    }

    private func bolt(tired: Bool) -> some View {
        Image(systemName: tired ? "bolt.slash.fill" : "bolt.fill")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(tired ? PuffyPalette.red : .yellow)
            .shadow(color: tired ? PuffyPalette.red.mix(with: .black, by: 0.3) : .orange, radius: 0, y: 1.5)
            .frame(width: 22)
    }

    private func bar(color: Color, tired: Bool, leading: Bool) -> some View {
        let fill = tired ? PuffyPalette.red : color
        return Capsule()
            .fill(PuffyPalette.ink.opacity(0.15))
            .frame(width: barWidth, height: 12)
            .overlay(alignment: leading ? .leading : .trailing) {
                Capsule()
                    .fill(LinearGradient(colors: [fill.mix(with: .white, by: 0.3), fill],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: barWidth * CGFloat(min(1, max(0, value))))
                    .animation(.spring(duration: 0.2), value: value)
            }
            .overlay(alignment: leading ? .leading : .trailing) {
                // Tick showing what one slam costs.
                Capsule().fill(PuffyPalette.ink.opacity(0.35))
                    .frame(width: 2, height: 8)
                    .offset(x: (leading ? 1 : -1) * barWidth * CGFloat(Stamina.slamCost))
            }
            .clipShape(Capsule())
    }
}
