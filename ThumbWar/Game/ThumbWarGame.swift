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
    static let exhaustedRecovery: Float = 1.2
    static let escapeDistance: Float = 0.45  // meters of wiggling needed to break a pin

    /// A slam leaps onto the opponent when they are this close and roughly
    /// in the direction the thumb is moving (or facing).
    static let lungeRange: Float = 0.095
    static let lungeCone: Float = 0.55       // cos of the max angle, about 57 degrees
    static let lungeHop: Float = 0.12        // seconds spent rising before dropping

    static func facing(_ side: Side) -> SIMD2<Float> { side == .left ? [1, 0] : [-1, 0] }
}

/// Stamina is only spent by slamming and mashing; it refills on its own,
/// faster while the thumb rests on the fist.
enum Stamina {
    static let regenRaised: Float = 1 / 10
    static let regenDown: Float = 1 / 2.5
    static let regenPinning: Float = 1 / 5
    static let slamCost: Float = 0.25
    static let mashCost: Float = 0.03
    static let tired: Float = 0.3            // below this the thumb trembles and slows down
    static let raiseAfterExhaustion: Float = 0.35

    /// 0.35...1: how responsive the thumb is.
    static func agility(_ s: Float) -> Float { 0.35 + 0.65 * s }
    /// 0.6...1.4: how strong a mash or wiggle is.
    static func power(_ s: Float) -> Float { 0.6 + 0.8 * s }
}

extension Arena {
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
    /// Set when the thumb flopped over from a lift with too little stamina.
    var exhausted = false
    /// Recent movement direction on the XZ plane, and how long ago it was set.
    var aim: SIMD2<Float> = .zero
    var aimAge: Float = 1
    /// Where a jumping slam is headed, if this slam is a leap onto the opponent.
    var lunge: SIMD2<Float>?
    var slamTime: Float = 0

    var horizontal: SIMD2<Float> { SIMD2(tip.x, tip.z) }
    var isTired: Bool { stamina < Stamina.tired }
}

enum GameEvent {
    case chantBeat(Int)
    case slam, lunge, land, tired
    case bump(Float)
    case pin, pinTick(Int), mash, escape
    case point(Side)
    case timeTick
    case matchOver(winner: Side?)
}

@Observable
final class ThumbWarGame {
    enum Mode { case vsCPU, twoPlayers }
    enum Stage: Equatable {
        case menu, chant(beat: Int), fight, pinned(by: Side), roundOver(winner: Side), matchOver(winner: Side?)
    }

    static let chantWords = ["1", "2", "3", "THUMB WAR!"]
    static let chantBeat: Float = 0.6
    static let pointsToWin = 3

    private(set) var stage: Stage = .menu
    private(set) var mode: Mode = .vsCPU
    private(set) var scores = [0, 0]
    private(set) var pinProgress: Float = 0
    private(set) var escapeProgress: Float = 0
    private(set) var stamina: [Float] = [1, 1]
    /// Whole seconds left, nil in "first to 3" matches.
    private(set) var secondsLeft: Int?
    private(set) var isOvertime = false
    private(set) var matchLength: MatchLength = .seconds60
    var isPaused = false

    @ObservationIgnored var slamControl: SlamControl = .lift
    @ObservationIgnored private(set) var thumbs: [ThumbState]
    @ObservationIgnored var onEvent: (GameEvent) -> Void = { _ in }
    @ObservationIgnored private(set) var time: Float = 0
    @ObservationIgnored private var stageTime: Float = 0
    @ObservationIgnored private var clock: Float?
    @ObservationIgnored private var accumulator: Float = 0
    @ObservationIgnored private var lastPinTick = -1
    @ObservationIgnored private var cpu = CPUBrain()

    init() {
        thumbs = Side.allCases.map { side in
            let t = Arena.startTargets[side.rawValue]
            return ThumbState(tip: [t.x, Arena.raisedHeight, t.y], target: t)
        }
    }

    func thumb(_ side: Side) -> ThumbState { thumbs[side.rawValue] }

    /// The CPU always plays with "lift" rules; humans use the setting.
    func control(for side: Side) -> SlamControl {
        mode == .vsCPU && side == .right ? .lift : slamControl
    }

    var isPlaying: Bool {
        switch stage {
        case .menu, .matchOver: false
        default: true
        }
    }

    /// Whether the slam button should look pressable.
    func canSlam(_ side: Side) -> Bool {
        switch stage {
        case .pinned: return true
        case .fight:
            let t = thumbs[side.rawValue]
            return t.phase == .raised && t.stamina >= Stamina.slamCost
        default: return false
        }
    }

    // MARK: - Flow

    func start(mode: Mode, length: MatchLength) {
        self.mode = mode
        matchLength = length
        scores = [0, 0]
        clock = length.seconds
        secondsLeft = clock.map { Int($0) }
        isOvertime = false
        isPaused = false
        cpu = CPUBrain()
        for i in thumbs.indices { thumbs[i].stamina = 1 }
        startRound()
    }

    func backToMenu() {
        isPaused = false
        stage = .menu
    }

    private func startRound() {
        for side in Side.allCases {
            let i = side.rawValue
            thumbs[i].target = Arena.startTargets[i]
            thumbs[i].phase = .raised
            thumbs[i].exhausted = false
            thumbs[i].recover = 0
            // Top up between points, but tiredness carries over a little.
            thumbs[i].stamina = max(thumbs[i].stamina, 0.7)
        }
        pinProgress = 0
        escapeProgress = 0
        setStage(.chant(beat: 0))
        onEvent(.chantBeat(0))
    }

    private func setStage(_ s: Stage) {
        stage = s
        stageTime = 0
    }

    // MARK: - Input (deltas are world meters on the XZ plane)

    func touchBegan(_ side: Side) {
        guard !isPaused else { return }
        thumbs[side.rawValue].isTouching = true
        if control(for: side) == .lift, thumbs[side.rawValue].phase == .pinning, case .pinned = stage {
            releasePin(by: side)
        }
    }

    func touchMoved(_ side: Side, delta: SIMD2<Float>) {
        guard !isPaused else { return }
        let i = side.rawValue
        if thumbs[i].phase == .pinned {
            escapeProgress += length(delta) / Arena.escapeDistance * Stamina.power(thumbs[i].stamina)
            return
        }
        recordAim(i, delta)
        thumbs[i].target = Arena.clamp(thumbs[i].target + delta, for: side)
    }

    func touchEnded(_ side: Side) {
        thumbs[side.rawValue].isTouching = false
    }

    /// Slam button: slams during the fight, mashes during a pin.
    func slamPressed(_ side: Side) {
        guard !isPaused else { return }
        let i = side.rawValue
        if case .pinned(let pinner) = stage {
            guard thumbs[i].stamina > 0 else { return }
            let power = Stamina.power(thumbs[i].stamina)
            thumbs[i].stamina = max(0, thumbs[i].stamina - Stamina.mashCost)
            if side == pinner {
                escapeProgress = max(0, escapeProgress - 0.06 * power)
            } else {
                escapeProgress += 0.09 * power
            }
            onEvent(.mash)
            return
        }
        guard stage == .fight, thumbs[i].phase == .raised, thumbs[i].stamina >= Stamina.slamCost else { return }
        slam(side)
    }

    // MARK: - Simulation

    func update(dt: Float) {
        guard !isPaused else { return }
        let step: Float = 1 / 120
        accumulator = min(accumulator + dt, 0.1)
        while accumulator >= step {
            tick(step)
            accumulator -= step
        }
        stamina = thumbs.map(\.stamina)
        let shownSeconds = clock.map { Int($0.rounded(.up)) }
        if shownSeconds != secondsLeft {
            secondsLeft = shownSeconds
            if let s = shownSeconds, s <= 5, s > 0, stage == .fight { onEvent(.timeTick) }
        }
    }

    private func tick(_ dt: Float) {
        time += dt
        stageTime += dt
        if mode == .vsCPU, isPlaying { cpu.think(game: self, dt: dt) }

        switch stage {
        case .menu:
            idleSway()
        case .chant(let beat):
            chant(beat: beat)
        case .fight:
            fightRules(dt)
            runClock(dt)
            if let c = clock, c <= 0 { endMatch() }
        case .pinned(let pinner):
            fightRules(dt)
            runClock(dt)
            pinProgress = min(stageTime / Arena.pinDuration, 1)
            let tickIndex = Int(pinProgress * 3)
            if tickIndex != lastPinTick, tickIndex < 3 {
                lastPinTick = tickIndex
                onEvent(.pinTick(tickIndex + 1))
            }
            if escapeProgress >= 1 {
                escapePin(pinner: pinner)
                if isOvertime { endMatch() }
            } else if pinProgress >= 1 {
                scorePoint(pinner)
            }
        case .roundOver:
            if stageTime > 1.8 { startRound() }
        case .matchOver:
            idleSway()
        }

        integrate(dt)
    }

    private func runClock(_ dt: Float) {
        guard var c = clock else { return }
        c = max(0, c - dt)
        clock = c
        if c == 0, case .pinned = stage { isOvertime = true }
    }

    private func scorePoint(_ side: Side) {
        scores[side.rawValue] += 1
        onEvent(.point(side))
        if clock == nil {
            if scores[side.rawValue] >= Self.pointsToWin { endMatch() } else { setStage(.roundOver(winner: side)) }
        } else if isOvertime || (clock ?? 0) <= 0 {
            endMatch()
        } else {
            setStage(.roundOver(winner: side))
        }
    }

    private func endMatch() {
        let winner: Side? = scores[0] == scores[1] ? nil : (scores[0] > scores[1] ? .left : .right)
        for i in thumbs.indices { thumbs[i].phase = .raised }
        setStage(.matchOver(winner: winner))
        onEvent(.matchOver(winner: winner))
    }

    private func idleSway() {
        for side in Side.allCases {
            let i = side.rawValue
            let wobble = sin(time * 1.6 + Float(i) * 2) * 0.012
            thumbs[i].phase = .raised
            thumbs[i].target = Arena.startTargets[i] + [wobble, cos(time * 1.2 + Float(i)) * 0.01]
        }
    }

    /// Thumbs bob side to side on every beat of "1, 2, 3, thumb war!".
    private func chant(beat: Int) {
        let lean: Float = beat.isMultiple(of: 2) ? -0.02 : 0.02
        for side in Side.allCases {
            let i = side.rawValue
            thumbs[i].phase = .raised
            thumbs[i].target = Arena.startTargets[i] + [lean, 0]
        }
        let isLast = beat + 1 == Self.chantWords.count
        if stageTime >= Self.chantBeat * (isLast ? 1.3 : 1) {
            if !isLast {
                setStage(.chant(beat: beat + 1))
                onEvent(.chantBeat(beat + 1))
            } else {
                setStage(.fight)
                for side in Side.allCases {
                    let i = side.rawValue
                    thumbs[i].target = Arena.startTargets[i]
                    // Nobody holding this thumb yet: let it rest instead of slamming.
                    if control(for: side) == .lift && !thumbs[i].isTouching { thumbs[i].phase = .down }
                }
            }
        }
    }

    private func slam(_ side: Side) {
        let i = side.rawValue
        thumbs[i].lunge = nil
        thumbs[i].slamTime = 0
        thumbs[i].phase = .slamming
        guard thumbs[i].stamina >= Stamina.slamCost else {
            // Too tired: the thumb just flops over, slowly.
            thumbs[i].exhausted = true
            onEvent(.tired)
            return
        }
        thumbs[i].stamina -= Stamina.slamCost
        thumbs[i].exhausted = false

        // Leap onto the opponent if they're close and ahead of us.
        let me = thumbs[i], them = thumbs[side.opponent.rawValue]
        let toThem = them.horizontal - me.horizontal
        let dist = length(toThem)
        let heading = me.aimAge < 0.4 && length(me.aim) > 0.1 ? normalize(me.aim) : Arena.facing(side)
        if dist < Arena.lungeRange, dist > 0.001, dot(toThem / dist, heading) > Arena.lungeCone,
           them.phase != .pinned {
            // Aim where they are now (plus a hint of where they're going): still dodgeable.
            let lead = SIMD2(them.velocity.x, them.velocity.z) * 0.08
            thumbs[i].lunge = Arena.clamp(them.horizontal + lead, for: side)
            thumbs[i].velocity.y += 0.9
            onEvent(.lunge)
        } else {
            onEvent(.slam)
        }
    }

    private func recordAim(_ i: Int, _ delta: SIMD2<Float>) {
        let d = length(delta)
        guard d > 0.0002 else { return }
        thumbs[i].aim = thumbs[i].aim * 0.6 + delta / d * 0.4
        thumbs[i].aimAge = 0
    }

    private func fightRules(_ dt: Float) {
        for side in Side.allCases {
            let i = side.rawValue
            let opp = side.opponent.rawValue

            switch thumbs[i].phase {
            case .raised:
                thumbs[i].stamina = min(1, thumbs[i].stamina + Stamina.regenRaised * dt)
                if control(for: side) == .lift && !thumbs[i].isTouching && stage == .fight {
                    slam(side)
                }
            case .slamming:
                let me = thumbs[i], them = thumbs[opp]
                let canPin = stage == .fight
                    && them.phase != .slamming && them.phase != .pinning
                    && distance(me.horizontal, them.horizontal) < Arena.pinRadius
                    && me.tip.y > them.tip.y - 0.005
                if canPin {
                    thumbs[i].phase = .pinning
                    thumbs[i].lunge = nil
                    thumbs[i].exhausted = false
                    thumbs[opp].phase = .pinned
                    thumbs[opp].velocity = .zero
                    escapeProgress = 0
                    pinProgress = 0
                    lastPinTick = -1
                    setStage(.pinned(by: side))
                    onEvent(.pin)
                } else if me.tip.y <= Arena.downHeight + 0.004 {
                    thumbs[i].phase = .down
                    thumbs[i].lunge = nil
                    thumbs[i].recover = me.exhausted ? Arena.exhaustedRecovery : Arena.missRecovery
                    onEvent(.land)
                }
            case .down:
                thumbs[i].stamina = min(1, thumbs[i].stamina + Stamina.regenDown * dt)
                thumbs[i].recover -= dt
                let needed: Float = thumbs[i].exhausted ? Stamina.raiseAfterExhaustion : 0.05
                let wantsUp = control(for: side) == .lift ? thumbs[i].isTouching : true
                if thumbs[i].recover <= 0 && wantsUp && thumbs[i].stamina >= needed && stage == .fight {
                    thumbs[i].phase = .raised
                    thumbs[i].exhausted = false
                }
            case .pinning:
                thumbs[i].stamina = min(1, thumbs[i].stamina + Stamina.regenPinning * dt)
                // Pinner leans in to follow the wiggling thumb underneath.
                thumbs[i].target = thumbs[opp].horizontal
            case .pinned:
                break
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
        thumbs[e].phase = control(for: pinner.opponent) == .lift && !thumbs[e].isTouching ? .down : .raised
        thumbs[e].recover = 0
        escapeProgress = 0
        setStage(.fight)
        onEvent(.escape)
    }

    private func integrate(_ dt: Float) {
        for i in thumbs.indices {
            var t = thumbs[i]
            t.aimAge += dt
            let agility = Stamina.agility(t.stamina)
            var kH: Float = 380 * agility
            let kV: Float
            var goalY: Float
            var horizontalGoal = t.target
            switch t.phase {
            case .raised:
                goalY = Arena.raisedHeight
                kV = 380
            case .slamming:
                t.slamTime += dt
                if let lunge = t.lunge {
                    // Hop up first, then drop onto the target.
                    horizontalGoal = lunge
                    kH = 1100
                    goalY = t.slamTime < Arena.lungeHop ? Arena.raisedHeight + 0.045 : Arena.downHeight - 0.02
                    kV = 900
                } else {
                    goalY = Arena.downHeight - 0.02
                    kV = t.exhausted ? 160 : 900 * (0.5 + 0.5 * t.stamina)
                }
            case .down:
                goalY = Arena.downHeight
                kV = 380
            case .pinning:
                goalY = Arena.pinStackHeight
                kV = 600
                kH = 380
            case .pinned:
                goalY = Arena.downHeight
                kV = 600
                horizontalGoal = t.horizontal
            }
            // Tired thumbs tremble and sag.
            if t.isTired && t.phase == .raised {
                let shake = (1 - t.stamina / Stamina.tired)
                horizontalGoal += SIMD2(sin(time * 43), cos(time * 37)) * 0.003 * shake
                goalY -= 0.018 * shake
            }
            let goal = SIMD3(horizontalGoal.x, goalY, horizontalGoal.y)
            let k = SIMD3(kH, kV, kH)
            let damping = 2 * k.squareRoot() * 0.5  // under-damped: a little bouncy
            let accel = k * (goal - t.tip) - damping * t.velocity
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
        let clamped = Arena.clamp(p, for: .right)
        recordAim(1, clamped - thumbs[1].target)
        thumbs[1].target = clamped
    }
}

/// A simple opponent that controls the right thumb with "lift" rules.
private struct CPUBrain {
    var reaction: Float = 0
    var orbitAngle: Float = .random(in: 0...(2 * .pi))
    var struggleRate: Float = .random(in: 0.22...0.42)
    var mashTimer: Float = 0
    var wantsToRest = false

    mutating func think(game: ThumbWarGame, dt: Float) {
        let me = game.thumb(.right), them = game.thumb(.left)
        let humanMashes = game.control(for: .left) == .button

        switch game.stage {
        case .fight, .pinned: break
        default:
            game.touchBegan(.right)
            return
        }

        switch me.phase {
        case .pinned:
            if humanMashes {
                mash(game: game, dt: dt, interval: 0.17...0.32)
            } else {
                let wiggle = SIMD2<Float>(cos(orbitAngle * 7), sin(orbitAngle * 5))
                orbitAngle += dt * 9
                game.touchMoved(.right, delta: wiggle * struggleRate * Arena.escapeDistance * dt)
            }
            return
        case .pinning:
            game.touchEnded(.right)
            if humanMashes { mash(game: game, dt: dt, interval: 0.2...0.35) }
            return
        case .down:
            wantsToRest = false
            if me.stamina > 0.5 { game.touchBegan(.right) }
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
        if them.phase == .down && me.stamina >= Stamina.slamCost {
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

        // Opponent hovering close in front: sometimes go for a jumping slam.
        let ahead = gap > 0.001 && dot((them.horizontal - me.horizontal) / gap, Arena.facing(.right)) > Arena.lungeCone
        if gap < 0.075, ahead, me.stamina > 0.55, Float.random(in: 0...1) < dt * 0.9 {
            game.touchEnded(.right)
            return
        }

        // Tired: back off and rest away from the opponent.
        if me.stamina < 0.3 { wantsToRest = true }
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

    private mutating func mash(game: ThumbWarGame, dt: Float, interval: ClosedRange<Float>) {
        mashTimer -= dt
        if mashTimer <= 0 {
            game.slamPressed(.right)
            mashTimer = .random(in: interval)
        }
    }
}
