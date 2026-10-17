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
        if mode == .vsCPU { return side == .left ? "You" : "CPU" }
        if let viewer { return side == viewer ? "You" : side.name }
        return side.name
    }

    var isMashing: Bool {
        if case .pinned = stage { true } else { false }
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
        SlamButton(side: side, enabled: game.canSlam(side), mashing: game.isMashing) { game.slamPressed(side) }
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
                        SlamButton(side: .left, enabled: game.canSlam(.left), mashing: game.isMashing, size: 104) {
                            game.slamPressed(.left)
                        }
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
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            ScorePill(side: viewer, score: game.scores[viewer.rawValue], label: game.label(viewer, viewer: viewer))
                            ScorePill(side: viewer.opponent, score: game.scores[viewer.opponent.rawValue],
                                      label: game.label(viewer.opponent, viewer: viewer))
                        }
                        StaminaBar(value: game.stamina[viewer.rawValue], side: .left, tint: viewer)
                    }
                    Spacer()
                    if settings.slamControl == .button && game.isPlaying {
                        SlamButton(side: viewer, enabled: game.canSlam(viewer), mashing: game.isMashing, size: 92) {
                            game.slamPressed(viewer)
                        }
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

    private var scale: CGFloat { compact ? 0.75 : 1 }

    var body: some View {
        switch game.stage {
        case .chant(let beat):
            PuffyPop(text: ThumbWarGame.chantWords[beat], size: (beat < 3 ? 130 : 88) * scale, color: chantColor(beat))
                .id(beat)
                .allowsHitTesting(false)
        case .pinned(let pinner):
            pin(pinner).allowsHitTesting(false)
        case .roundOver(let winner):
            PuffyPop(text: "+1 \(game.label(winner, viewer: viewer))!", size: 60 * scale, color: PuffyPalette.team(winner))
                .allowsHitTesting(false)
        case .matchOver(let winner):
            result(winner)
        case .menu, .fight:
            EmptyView()
        }
    }

    private func chantColor(_ beat: Int) -> Color {
        [PuffyPalette.blue, .yellow, PuffyPalette.red, .orange][beat]
    }

    private func pin(_ pinner: Side) -> some View {
        let pinned = pinner.opponent
        let count = min(3, Int(game.pinProgress * 3) + 1)
        let mash = settings.slamControl == .button
        let line: String = switch viewer {
        case pinned?: mash ? "MASH to escape!" : "Wiggle to escape!"
        case pinner?: mash ? "MASH to hold!" : "Hold it!"
        default: mash ? "\(game.label(pinned)): MASH to escape! · \(game.label(pinner)): MASH to hold!"
                      : "\(game.label(pinned)), wiggle to escape!"
        }
        return VStack(spacing: 6) {
            PuffyPop(text: "\(count)", size: 72 * scale, color: PuffyPalette.team(pinner))
                .id(count)
            Text(line)
                .font(.system(compact ? .subheadline : .headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(.black.opacity(0.25), in: Capsule())
            TugBar(progress: game.escapeProgress, escaper: pinned)
                .frame(width: 200)
        }
        .padding(.top, compact ? 40 : 64)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func result(_ winner: Side?) -> some View {
        let title: String = {
            guard let winner else { return "Draw!" }
            if game.mode == .vsCPU { return winner == .left ? "You win!" : "You lose!" }
            if let viewer { return winner == viewer ? "You win!" : "You lose!" }
            return "\(winner.name) wins!"
        }()
        return VStack(spacing: 12) {
            PuffyPop(text: title, size: 68 * scale, color: winner.map(PuffyPalette.team) ?? .yellow)
            Text("\(game.label(.left, viewer: viewer)) \(game.scores[0])  –  \(game.scores[1]) \(game.label(.right, viewer: viewer))")
                .font(.system(compact ? .headline : .title2, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 16).padding(.vertical, 6)
                .background(.black.opacity(0.3), in: Capsule())
            HStack(spacing: 14) {
                PuffyButton(title: "Rematch", color: PuffyPalette.blue, compact: compact) {
                    feedback.tap()
                    game.start(mode: game.mode, length: game.matchLength)
                }
                PuffyButton(title: "Menu", color: .orange, compact: compact) {
                    feedback.tap()
                    game.backToMenu()
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

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    PuffyText(text: "THUMB WAR", size: 60, color: .orange)
                    PuffyText(text: "THUMB WAR", size: 44, color: .orange)
                }
                .padding(.top, 50)
                Spacer()
                HStack(spacing: 14) {
                    PuffyButton(title: "Play vs CPU", color: PuffyPalette.blue) {
                        feedback.tap()
                        game.start(mode: .vsCPU, length: settings.matchLength)
                    }
                    PuffyButton(title: "2 Players", color: PuffyPalette.red) {
                        feedback.tap()
                        game.start(mode: .twoPlayers, length: settings.matchLength)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)

            RoundIconButton(systemName: "gearshape.fill", color: .purple) {
                feedback.tap()
                showSettings = true
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
    }
}

struct PauseMenu: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let feedback: GameFeedback
    @Binding var showSettings: Bool

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                PuffyText(text: "Paused", size: 56, color: .orange)
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
            game.start(mode: game.mode, length: settings.matchLength)
        }
        PuffyButton(title: "Settings", color: .purple) {
            feedback.tap()
            showSettings = true
        }
        PuffyButton(title: "Quit", color: PuffyPalette.red) {
            feedback.tap()
            game.backToMenu()
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
            Text(settings.slamControl == .lift ? "Drag to move · Lift to slam" : "Drag to move · Tap SLAM")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.black.opacity(0.18), in: Capsule())
                .allowsHitTesting(false)
        }
    }
}

struct ScorePill: View {
    let side: Side
    let score: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.system(.headline, design: .rounded, weight: .heavy))
            Text("\(score)")
                .font(.system(.title3, design: .rounded, weight: .black))
                .contentTransition(.numericText())
                .animation(.spring, value: score)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(PuffySurface(shape: Capsule(), color: PuffyPalette.team(side), depth: 4))
        .padding(.bottom, 4)
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
            .foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(PuffySurface(shape: Capsule(), color: urgent ? .red : .gray, depth: 4))
            .padding(.bottom, 4)
            .scaleEffect(urgent ? 1.08 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.6), value: seconds)
            .allowsHitTesting(false)
    }
}

/// Escape meter during a pin: fills with the pinned player's color.
struct TugBar: View {
    let progress: Float
    let escaper: Side

    var body: some View {
        Capsule()
            .fill(PuffyPalette.team(escaper.opponent).opacity(0.85))
            .frame(height: 16)
            .overlay(alignment: .leading) {
                GeometryReader { geo in
                    Capsule()
                        .fill(PuffyPalette.team(escaper))
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))))
                        .animation(.spring(duration: 0.15), value: progress)
                }
            }
            .overlay(Capsule().stroke(.white, lineWidth: 3))
    }
}

struct StaminaBar: View {
    let value: Float
    /// Which edge the bar grows from.
    let side: Side
    /// Bar color; defaults to `side`.
    var tint: Side?

    var body: some View {
        let tired = value < Stamina.tired
        let leading = side == .left
        VStack(alignment: leading ? .leading : .trailing, spacing: 4) {
            Text(tired ? "TIRED!" : "STAMINA")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(tired ? Color.red : .white.opacity(0.9))
            Capsule()
                .fill(.black.opacity(0.2))
                .frame(width: 120, height: 12)
                .overlay(alignment: leading ? .leading : .trailing) {
                    Capsule()
                        .fill(tired ? Color.red : PuffyPalette.team(tint ?? side))
                        .frame(width: 120 * CGFloat(max(0, value)))
                }
                .overlay(alignment: leading ? .leading : .trailing) {
                    // Tick showing what one slam costs.
                    Rectangle().fill(.white.opacity(0.7))
                        .frame(width: 2, height: 12)
                        .offset(x: (leading ? 1 : -1) * 120 * CGFloat(Stamina.slamCost))
                }
                .overlay(Capsule().stroke(.white.opacity(0.8), lineWidth: 2))
        }
        .allowsHitTesting(false)
    }
}
