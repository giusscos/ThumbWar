//
//  ThumbWarGame.swift
//  ThumbWar
//
//  Rules and thumb physics. Pure simd, no rendering, so the same simulation
//  can later run on the host device of an AR multiplayer session.
//

import Foundation
import Observation
import simd

enum Side: Int, CaseIterable {
    case left = 0, right = 1

    var opponent: Side { self == .left ? .right : .left }
    var name: String { self == .left ? "Blue" : "Red" }
}

/// World-space tuning, in meters. The clasped fists sit at the origin.
enum Arena {
    static let bases: [SIMD3<Float>] = [[-0.03, 0.07, -0.005], [0.03, 0.07, -0.005]]
    static let startTargets: [SIMD2<Float>] = [[-0.045, 0.01], [0.045, 0.01]]
    static let raisedHeight: Float = 0.175
    static let downHeight: Float = 0.112
    static let pinStackHeight: Float = downHeight + 0.038
    static let tipRadius: Float = 0.022
    static let collisionDistance: Float = 0.044
    static let pinRadius: Float = 0.032
    static let reach: Float = 0.12
    static let bounds = (x: Float(0.105), zMin: Float(-0.065), zMax: Float(0.07))

    static let pinDuration: Float = 3
    static let missRecovery: Float = 0.35
    static let exhaustedRecovery: Float = 0.8
    static let staminaDrain: Float = 1 / 5   // full bar lasts 5 s raised
    static let staminaRegen: Float = 1 / 2.5
    static let escapeDistance: Float = 0.45  // meters of wiggling needed to break a pin

    static func clamp(_ p: SIMD2<Float>, for side: Side) -> SIMD2<Float> {
        var p = SIMD2(min(max(p.x, -bounds.x), bounds.x), min(max(p.y, bounds.zMin), bounds.zMax))
        let base = SIMD2(bases[side.rawValue].x, bases[side.rawValue].z)
        let offset = p - base
        if length(offset) > reach { p = base + normalize(offset) * reach }
        return p
    }
}

struct ThumbState {
    enum Phase: Equatable { case raised, slamming, down, pinning, pinned }

    var tip: SIMD3<Float>
    var velocity: SIMD3<Float> = .zero
    var target: SIMD2<Float>
    var phase: Phase = .raised
    var isTouching = false
    var recover: Float = 0
    var stamina: Float = 1
    var exhausted = false

    var horizontal: SIMD2<Float> { SIMD2(tip.x, tip.z) }
}

enum GameEvent {
    case chantBeat, slam, miss, bump(Float), pin, escape, roundWon(Side), matchWon(Side)
}

@Observable
final class ThumbWarGame {
    enum Mode { case vsCPU, twoPlayers }
    enum Stage: Equatable {
        case menu, chant(beat: Int), fight, pinned(by: Side), roundOver(winner: Side), matchOver(winner: Side)
    }

    static let chantWords = ["One", "Two", "Three", "Four", "I declare a", "THUMB WAR!"]
    static let chantBeat: Float = 0.55
    let roundsToWin = 3

    private(set) var stage: Stage = .menu
    private(set) var mode: Mode = .vsCPU
    private(set) var scores = [0, 0]
    private(set) var pinProgress: Float = 0
    private(set) var escapeProgress: Float = 0
    private(set) var stamina: [Float] = [1, 1]

    @ObservationIgnored private(set) var thumbs: [ThumbState]
    @ObservationIgnored var onEvent: (GameEvent) -> Void = { _ in }
    @ObservationIgnored private var stageTime: Float = 0
    @ObservationIgnored private var accumulator: Float = 0
    @ObservationIgnored private var cpu = CPUBrain()

    init() {
        thumbs = Side.allCases.map { side in
            let t = Arena.startTargets[side.rawValue]
            return ThumbState(tip: [t.x, Arena.raisedHeight, t.y], target: t)
        }
    }

    func thumb(_ side: Side) -> ThumbState { thumbs[side.rawValue] }

    // MARK: - Flow

    func start(mode: Mode) {
        self.mode = mode
        scores = [0, 0]
        cpu = CPUBrain()
        startRound()
    }

    func backToMenu() { stage = .menu }

    private func startRound() {
        for side in Side.allCases {
            let i = side.rawValue
            thumbs[i].target = Arena.startTargets[i]
            thumbs[i].phase = .raised
            thumbs[i].stamina = 1
            thumbs[i].exhausted = false
            thumbs[i].recover = 0
        }
        pinProgress = 0
        escapeProgress = 0
        setStage(.chant(beat: 0))
        onEvent(.chantBeat)
    }

    private func setStage(_ s: Stage) {
        stage = s
        stageTime = 0
    }

    // MARK: - Input (deltas are world meters on the XZ plane)

    func touchBegan(_ side: Side) {
        thumbs[side.rawValue].isTouching = true
        if thumbs[side.rawValue].phase == .pinning, case .pinned = stage {
            releasePin(by: side)
        }
    }

    func touchMoved(_ side: Side, delta: SIMD2<Float>) {
        let i = side.rawValue
        if thumbs[i].phase == .pinned {
            escapeProgress += length(delta) / Arena.escapeDistance
            return
        }
        thumbs[i].target = Arena.clamp(thumbs[i].target + delta, for: side)
    }

    func touchEnded(_ side: Side) {
        thumbs[side.rawValue].isTouching = false
    }

    // MARK: - Simulation

    func update(dt: Float) {
        let step: Float = 1 / 120
        accumulator = min(accumulator + dt, 0.1)
        while accumulator >= step {
            tick(step)
            accumulator -= step
        }
        stamina = thumbs.map(\.stamina)
    }

    private func tick(_ dt: Float) {
        stageTime += dt
        if mode == .vsCPU, stage != .menu { cpu.think(game: self, dt: dt) }

        switch stage {
        case .menu:
            idleSway(dt)
        case .chant(let beat):
            chant(beat: beat, dt: dt)
        case .fight:
            fightRules(dt)
        case .pinned(let pinner):
            fightRules(dt)
            pinProgress = min(stageTime / Arena.pinDuration, 1)
            if escapeProgress >= 1 {
                escapePin(pinner: pinner)
            } else if pinProgress >= 1 {
                scores[pinner.rawValue] += 1
                if scores[pinner.rawValue] >= roundsToWin {
                    setStage(.matchOver(winner: pinner))
                    onEvent(.matchWon(pinner))
                } else {
                    setStage(.roundOver(winner: pinner))
                    onEvent(.roundWon(pinner))
                }
            }
        case .roundOver:
            if stageTime > 2.2 { startRound() }
        case .matchOver:
            break
        }

        integrate(dt)
    }

    private func idleSway(_ dt: Float) {
        for side in Side.allCases {
            let i = side.rawValue
            let wobble = sin(stageTime * 1.6 + Float(i) * 2) * 0.012
            thumbs[i].phase = .raised
            thumbs[i].target = Arena.startTargets[i] + [wobble, cos(stageTime * 1.2 + Float(i)) * 0.01]
        }
    }

    /// Thumbs bob side to side in time with "one, two, three, four...".
    private func chant(beat: Int, dt: Float) {
        let lean: Float = beat.isMultiple(of: 2) ? -0.02 : 0.02
        for side in Side.allCases {
            let i = side.rawValue
            thumbs[i].phase = .raised
            thumbs[i].target = Arena.startTargets[i] + [lean, 0]
        }
        if stageTime >= Self.chantBeat {
            if beat + 1 < Self.chantWords.count {
                setStage(.chant(beat: beat + 1))
                onEvent(.chantBeat)
            } else {
                setStage(.fight)
                for i in thumbs.indices { thumbs[i].target = Arena.startTargets[i] }
            }
        }
    }

    private func fightRules(_ dt: Float) {
        for side in Side.allCases {
            let i = side.rawValue
            let opp = side.opponent.rawValue

            switch thumbs[i].phase {
            case .raised:
                thumbs[i].stamina -= Arena.staminaDrain * dt
                if thumbs[i].stamina <= 0 {
                    thumbs[i].stamina = 0
                    thumbs[i].exhausted = true
                    thumbs[i].phase = .slamming
                } else if !thumbs[i].isTouching {
                    thumbs[i].phase = .slamming
                    onEvent(.slam)
                }
            case .slamming:
                let me = thumbs[i], them = thumbs[opp]
                let canPin = stage == .fight
                    && them.phase != .slamming && them.phase != .pinning
                    && distance(me.horizontal, them.horizontal) < Arena.pinRadius
                    && me.tip.y > them.tip.y - 0.005
                if canPin {
                    thumbs[i].phase = .pinning
                    thumbs[opp].phase = .pinned
                    thumbs[opp].velocity = .zero
                    escapeProgress = 0
                    pinProgress = 0
                    setStage(.pinned(by: side))
                    onEvent(.pin)
                } else if me.tip.y <= Arena.downHeight + 0.004 {
                    thumbs[i].phase = .down
                    thumbs[i].recover = me.exhausted ? Arena.exhaustedRecovery : Arena.missRecovery
                    thumbs[i].exhausted = false
                    onEvent(.miss)
                }
            case .down:
                thumbs[i].stamina = min(1, thumbs[i].stamina + Arena.staminaRegen * dt)
                thumbs[i].recover -= dt
                if thumbs[i].recover <= 0 && thumbs[i].isTouching && thumbs[i].stamina > 0.15 {
                    thumbs[i].phase = .raised
                }
            case .pinning:
                // Pinner leans in to follow the wiggling thumb underneath.
                thumbs[i].target = thumbs[opp].horizontal
            case .pinned:
                thumbs[i].stamina = min(1, thumbs[i].stamina + Arena.staminaRegen * dt)
            }
        }
    }

    private func releasePin(by pinner: Side) {
        thumbs[pinner.rawValue].phase = .raised
        thumbs[pinner.opponent.rawValue].phase = .down
        thumbs[pinner.opponent.rawValue].recover = 0.2
        setStage(.fight)
    }

    private func escapePin(pinner: Side) {
        let p = pinner.rawValue, e = pinner.opponent.rawValue
        thumbs[p].phase = .down
        thumbs[p].recover = 0.6
        let away = normalize(thumbs[p].horizontal - thumbs[e].horizontal + [0.0001, 0])
        thumbs[p].velocity += SIMD3(away.x, 0.6, away.y) * 0.8
        thumbs[e].phase = thumbs[e].isTouching ? .raised : .down
        thumbs[e].recover = 0
        escapeProgress = 0
        setStage(.fight)
        onEvent(.escape)
    }

    private func integrate(_ dt: Float) {
        for i in thumbs.indices {
            var t = thumbs[i]
            let goalY: Float
            var stiffness: Float = 380
            var horizontalGoal = t.target
            switch t.phase {
            case .raised: goalY = Arena.raisedHeight
            case .slamming: goalY = Arena.downHeight - 0.02; stiffness = 900
            case .down: goalY = Arena.downHeight
            case .pinning: goalY = Arena.pinStackHeight
            case .pinned:
                goalY = Arena.downHeight
                horizontalGoal = t.horizontal
            }
            let goal = SIMD3(horizontalGoal.x, goalY, horizontalGoal.y)
            let damping = 2 * sqrt(stiffness) * 0.5  // under-damped: a little bouncy
            let accel = stiffness * (goal - t.tip) - damping * t.velocity
            t.velocity += accel * dt
            t.tip += t.velocity * dt
            t.tip.y = max(t.tip.y, Arena.downHeight - 0.004)
            let clamped = Arena.clamp(t.horizontal, for: Side(rawValue: i)!)
            t.tip.x = clamped.x
            t.tip.z = clamped.y
            thumbs[i] = t
        }
        resolveCollision()
    }

    /// Tips are soft balls: they push each other apart unless one is pinning the other.
    private func resolveCollision() {
        if thumbs[0].phase == .pinning || thumbs[1].phase == .pinning { return }
        let delta = thumbs[1].tip - thumbs[0].tip
        let dist = length(delta)
        guard dist < Arena.collisionDistance, dist > 0.0001 else { return }
        let n = delta / dist
        let push = (Arena.collisionDistance - dist) / 2
        thumbs[0].tip -= n * push
        thumbs[1].tip += n * push
        let closing = dot(thumbs[0].velocity - thumbs[1].velocity, n)
        if closing > 0 {
            let impulse = n * closing * 0.9
            thumbs[0].velocity -= impulse
            thumbs[1].velocity += impulse
            if closing > 0.25 { onEvent(.bump(closing)) }
        }
    }

    // MARK: - CPU hooks

    fileprivate func cpuSetTarget(_ p: SIMD2<Float>) {
        thumbs[1].target = Arena.clamp(p, for: .right)
    }
}

/// A simple opponent that controls the right thumb.
private struct CPUBrain {
    var reaction: Float = 0
    var orbitAngle: Float = .random(in: 0...(2 * .pi))
    var struggleRate: Float = .random(in: 0.22...0.42)
    var wantsToRest = false

    mutating func think(game: ThumbWarGame, dt: Float) {
        let me = game.thumb(.right), them = game.thumb(.left)

        switch game.stage {
        case .fight, .pinned: break
        default:
            game.touchBegan(.right)
            return
        }

        switch me.phase {
        case .pinned:
            let wiggle = SIMD2<Float>(cos(orbitAngle * 7), sin(orbitAngle * 5))
            orbitAngle += dt * 9
            game.touchMoved(.right, delta: wiggle * struggleRate * Arena.escapeDistance * dt)
            return
        case .pinning:
            game.touchEnded(.right)
            return
        case .down:
            wantsToRest = false
            if me.stamina > 0.35 { game.touchBegan(.right) }
            return
        case .slamming:
            return
        case .raised:
            break
        }

        let gap = distance(me.horizontal, them.horizontal)

        // Dodge an incoming slam.
        if them.phase == .slamming && gap < 0.06 {
            let away = normalize(me.horizontal - them.horizontal + [0.001, 0])
            game.cpuSetTarget(me.horizontal + away * 0.06)
            return
        }

        // Punish a thumb that is down.
        if them.phase == .down {
            game.cpuSetTarget(them.horizontal)
            if gap < 0.014 {
                reaction += dt
                if reaction > 0.12 {
                    reaction = 0
                    game.touchEnded(.right)
                }
            }
            return
        }
        reaction = 0

        // Tired: back off and rest away from the opponent.
        if me.stamina < 0.2 { wantsToRest = true }
        if wantsToRest {
            let away = normalize(me.horizontal - them.horizontal + [0.001, 0])
            game.cpuSetTarget(me.horizontal + away * 0.08)
            if gap > 0.07 { game.touchEnded(.right) }
            return
        }

        // Circle the opponent, looking for an opening.
        orbitAngle += dt * 1.8
        let orbit = SIMD2(cos(orbitAngle), sin(orbitAngle)) * 0.045
        game.cpuSetTarget(them.horizontal + orbit)
    }
}
