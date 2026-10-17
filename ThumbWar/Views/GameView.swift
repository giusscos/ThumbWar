//
//  GameView.swift
//  ThumbWar
//

import RealityKit
import SwiftUI
import UIKit

struct GameView: View {
    @State private var game = ThumbWarGame()
    @State private var scene = ArenaScene()
    @State private var haptics = Haptics()

    /// Screen points to world meters for drag input.
    private let dragScale: Float = 0.0008

    var body: some View {
        ZStack {
            RealityView { content in
                content.camera = .virtual
                try? scene.build(in: content, game: game)
                game.onEvent = { [haptics] in haptics.play($0) }
            }
            .ignoresSafeArea()

            TouchSurface(
                sideForLocation: { point, size in
                    switch game.mode {
                    case .vsCPU: .left
                    case .twoPlayers: point.x < size.width / 2 ? .left : .right
                    }
                },
                began: { game.touchBegan($0) },
                moved: { side, d in
                    game.touchMoved(side, delta: SIMD2(Float(d.x), Float(d.y)) * dragScale)
                },
                ended: { game.touchEnded($0) }
            )
            .ignoresSafeArea()

            HUDView(game: game)
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-autostartCPU") { game.start(mode: .vsCPU) }
            #endif
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }
}

private struct HUDView: View {
    let game: ThumbWarGame

    var body: some View {
        ZStack {
            if game.stage != .menu {
                VStack {
                    HStack(alignment: .top) {
                        ScorePill(side: .left, score: game.scores[0], total: game.roundsToWin,
                                  label: game.mode == .vsCPU ? "You" : "Blue")
                        Spacer()
                        ScorePill(side: .right, score: game.scores[1], total: game.roundsToWin,
                                  label: game.mode == .vsCPU ? "CPU" : "Red")
                    }
                    Spacer()
                    HStack(alignment: .bottom) {
                        StaminaBar(value: game.stamina[0], side: .left)
                        Spacer()
                        if game.stage == .fight {
                            Text("Drag to move · Lift to slam")
                                .font(.system(.footnote, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(.black.opacity(0.18), in: Capsule())
                        }
                        Spacer()
                        StaminaBar(value: game.stamina[1], side: .right)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .allowsHitTesting(false)
            }

            centerBanner
        }
    }

    @ViewBuilder private var centerBanner: some View {
        switch game.stage {
        case .menu:
            MenuView(game: game)
        case .chant(let beat):
            BigText(ThumbWarGame.chantWords[beat], color: .white)
                .id(beat)
                .transition(.scale(scale: 1.6).combined(with: .opacity))
                .animation(.spring(duration: 0.3, bounce: 0.5), value: beat)
                .allowsHitTesting(false)
        case .pinned(let pinner):
            VStack(spacing: 8) {
                BigText("\(min(3, Int(game.pinProgress * 3) + 1))…", color: Color(PuffyMaterials.teamColor(pinner)))
                Text(game.mode == .vsCPU && pinner == .right ? "Wiggle to escape!" :
                        "\(pinner.opponent.name), wiggle to escape!")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(.white)
                ProgressView(value: min(game.escapeProgress, 1))
                    .tint(Color(PuffyMaterials.teamColor(pinner.opponent)))
                    .frame(width: 160)
            }
            .padding(.top, 140)
            .allowsHitTesting(false)
        case .roundOver(let winner):
            BigText(winnerTitle(winner) + " pins it!", color: Color(PuffyMaterials.teamColor(winner)))
                .allowsHitTesting(false)
        case .matchOver(let winner):
            VStack(spacing: 18) {
                BigText(winnerTitle(winner) + (game.mode == .vsCPU && winner == .left ? " win!" : " wins!"),
                        color: Color(PuffyMaterials.teamColor(winner)))
                HStack(spacing: 14) {
                    PuffyButton(title: "Rematch", color: Color(PuffyMaterials.teamColor(.left))) {
                        game.start(mode: game.mode)
                    }
                    PuffyButton(title: "Menu", color: .orange) { game.backToMenu() }
                }
            }
        case .fight:
            EmptyView()
        }
    }

    private func winnerTitle(_ side: Side) -> String {
        guard game.mode == .vsCPU else { return side.name }
        return side == .left ? "You" : "CPU"
    }
}

private struct MenuView: View {
    let game: ThumbWarGame

    var body: some View {
        VStack(spacing: 14) {
            BigText("THUMB WAR", color: .white)
            Spacer()
            HStack(spacing: 14) {
                PuffyButton(title: "Play vs CPU", color: Color(PuffyMaterials.teamColor(.left))) {
                    game.start(mode: .vsCPU)
                }
                PuffyButton(title: "2 Players", color: Color(PuffyMaterials.teamColor(.right))) {
                    game.start(mode: .twoPlayers)
                }
            }
        }
        .padding(.vertical, 24)
    }
}

private struct BigText: View {
    let text: String
    let color: Color
    init(_ text: String, color: Color) { self.text = text; self.color = color }

    var body: some View {
        Text(text)
            .font(.system(size: 52, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 4)
            .shadow(color: .black.opacity(0.2), radius: 10)
    }
}

private struct PuffyButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 14)
                .background(color.gradient, in: Capsule())
                .shadow(color: color.opacity(0.5), radius: 0, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }
}

private struct ScorePill: View {
    let side: Side
    let score: Int
    let total: Int
    let label: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(.system(.headline, design: .rounded, weight: .heavy))
            HStack(spacing: 4) {
                ForEach(0..<total, id: \.self) { i in
                    Circle()
                        .fill(i < score ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 11, height: 11)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(Color(PuffyMaterials.teamColor(side)).gradient, in: Capsule())
    }
}

private struct StaminaBar: View {
    let value: Float
    let side: Side

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STAMINA").font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            Capsule()
                .fill(.black.opacity(0.2))
                .frame(width: 110, height: 10)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color(PuffyMaterials.teamColor(side)))
                        .frame(width: 110 * CGFloat(max(0, value)))
                }
        }
    }
}

@MainActor
private final class Haptics {
    private let light = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    func play(_ event: GameEvent) {
        switch event {
        case .chantBeat, .slam: light.impactOccurred(intensity: 0.6)
        case .miss: light.impactOccurred()
        case .bump(let speed): heavy.impactOccurred(intensity: CGFloat(min(1, speed)))
        case .pin: heavy.impactOccurred()
        case .escape: notify.notificationOccurred(.warning)
        case .roundWon, .matchWon: notify.notificationOccurred(.success)
        }
    }
}
