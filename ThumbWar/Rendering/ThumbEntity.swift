//
//  ThumbEntity.swift
//  ThumbWar
//
//  One fighter: the bendy puffy tube, a team headband and a cartoon face
//  that always turns toward the camera.
//

import RealityKit
import UIKit
import simd

final class ThumbEntity: Entity {
    enum Mood { case fierce, worried, happy }

    private let side: Side
    private let tube: PuffyTube
    private let body: ModelEntity
    private let headband: ModelEntity
    private let knot: ModelEntity
    private let face = Entity()
    private var eyes: [ModelEntity] = []
    private var pupils: [ModelEntity] = []
    private var brows: [ModelEntity] = []
    private let mouth: ModelEntity
    private let sweat: ModelEntity
    private var sweatPhase: Float = 0
    private var blinkTimer: Float = .random(in: 1.5...4)
    private let baseRadius: Float = 0.02

    init(side: Side) throws {
        self.side = side
        tube = try PuffyTube()
        body = ModelEntity(mesh: tube.resource, materials: [PuffyMaterials.skin()])

        let team = PuffyMaterials.glossy(PuffyMaterials.teamColor(side), roughness: 0.4)
        headband = ModelEntity(mesh: .generateCylinder(height: 0.009, radius: 1), materials: [team])
        knot = ModelEntity(mesh: .generateSphere(radius: 0.0055), materials: [team])

        let white = PuffyMaterials.glossy(.white, roughness: 0.15)
        let black = PuffyMaterials.glossy(UIColor(white: 0.06, alpha: 1), roughness: 0.1)
        let browMat = PuffyMaterials.matte(UIColor(red: 0.35, green: 0.18, blue: 0.1, alpha: 1))
        mouth = ModelEntity(mesh: .generateSphere(radius: 1), materials: [PuffyMaterials.matte(UIColor(red: 0.45, green: 0.12, blue: 0.12, alpha: 1))])

        var drop = PuffyMaterials.glossy(UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1), roughness: 0.05)
        drop.blending = .transparent(opacity: 0.85)
        sweat = ModelEntity(mesh: .generateSphere(radius: 0.0028), materials: [drop])

        super.init()

        addChild(body)
        addChild(headband)
        addChild(knot)
        addChild(face)
        for x: Float in [-1, 1] {
            let eye = ModelEntity(mesh: .generateSphere(radius: 0.0052), materials: [white])
            eye.position = [x * 0.0068, 0.003, 0]
            eye.scale = [1, 1.15, 0.6]
            face.addChild(eye)
            eyes.append(eye)

            let pupil = ModelEntity(mesh: .generateSphere(radius: 0.0027), materials: [black])
            face.addChild(pupil)
            pupils.append(pupil)

            let brow = ModelEntity(mesh: .generateBox(width: 0.0085, height: 0.0022, depth: 0.0022, cornerRadius: 0.0011),
                                   materials: [browMat])
            brow.position = [x * 0.0068, 0.0105, 0.0015]
            face.addChild(brow)
            brows.append(brow)
        }
        mouth.position = [0, -0.0062, 0.0004]
        mouth.scale = [0.0035, 0.0016, 0.0012]
        face.addChild(mouth)
        face.addChild(sweat)
        face.scale = SIMD3(repeating: 1.3)
    }

    @MainActor required init() { fatalError("use init(side:)") }

    func update(state: ThumbState, opponentTip: SIMD3<Float>, cameraPosition: SIMD3<Float>,
                mood: Mood, dt: Float) {
        let base = Arena.bases[side.rawValue]
        let tip = state.tip
        let up = SIMD3<Float>(0, 1, 0)
        let press = simd_clamp((Arena.raisedHeight - tip.y) / (Arena.raisedHeight - Arena.downHeight), 0, 1)
        var horizontal = tip - base
        horizontal.y = 0
        let hDir = length(horizontal) > 1e-4 ? normalize(horizontal) : SIMD3<Float>(0, 0, 1)

        // Knuckle rises straight up, then the tip curls down as the thumb presses.
        let curve = BezierCurve(
            p0: base,
            p1: base + up * 0.06 + horizontal * 0.15,
            p2: tip + up * (-0.035 * (1 - press) + 0.025 * press) - hDir * 0.035 * press,
            p3: tip
        )
        let squash: Float = switch state.phase {
        case .pinned: 1.25
        case .pinning: 1.08
        default: 1
        }
        tube.update(curve: curve, baseRadius: baseRadius, squash: squash)

        // Headband wraps the thumb just below the tip.
        let bandS: Float = 0.78
        let bandT = curve.tangent(bandS)
        let bandR = PuffyTube.radius(at: bandS, base: baseRadius) * 1.12
        headband.position = curve.point(bandS)
        headband.orientation = simd_quatf(from: up, to: bandT)
        headband.scale = [bandR, 1, bandR]

        // Face basis: y roughly along the thumb but biased upward so the face
        // never turns upside down when the tip curls over; z toward the camera.
        let t = normalize(curve.tangent(1) + up * 1.2)
        let tipR = PuffyTube.radius(at: 1, base: baseRadius) * squash
        var toCam = normalize(cameraPosition - tip)
        toCam = toCam - dot(toCam, t) * t
        let f = length(toCam) > 1e-4 ? normalize(toCam) : SIMD3<Float>(0, 0, 1)
        let s = cross(t, f)
        face.position = tip + t * (tipR * 0.2) + f * (tipR * 0.8)
        face.orientation = simd_quatf(simd_float3x3(columns: (s, t, f)))
        knot.position = curve.point(bandS) - f * bandR

        // Pupils glance at the opponent.
        let look = opponentTip - face.position
        let lookX = simd_clamp(dot(look, s) * 40, -1, 1) * 0.0019
        let lookY = simd_clamp(dot(look, t) * 40, -1, 1) * 0.0012
        for (i, x) in [Float(-1), 1].enumerated() {
            pupils[i].position = [x * 0.0068 + lookX, 0.003 + lookY, 0.0032]
        }

        // Expression.
        let browAngle: Float = switch mood {
        case .fierce: 0.38
        case .worried: -0.42
        case .happy: -0.15
        }
        brows[0].orientation = simd_quatf(angle: -browAngle, axis: [0, 0, 1])
        brows[1].orientation = simd_quatf(angle: browAngle, axis: [0, 0, 1])
        mouth.scale = switch mood {
        case .fierce: [0.0032, 0.0011, 0.0012]
        case .worried: [0.0022, 0.0026, 0.0012]
        case .happy: [0.0042, 0.0024, 0.0012]
        }

        // A sweat drop slides down the side of a tired thumb.
        sweat.isEnabled = state.isTired
        if state.isTired {
            sweatPhase = (sweatPhase + dt * 0.9).truncatingRemainder(dividingBy: 1)
            sweat.position = [0.0125, 0.012 - sweatPhase * 0.014, 0.001]
            sweat.scale = [1, 1.5, 1] * (0.6 + 0.4 * min(1, sweatPhase * 4))
        }

        // Blink now and then.
        blinkTimer -= dt
        let blinking = blinkTimer < 0.1
        if blinkTimer < 0 { blinkTimer = .random(in: 1.5...4.5) }
        for (i, eye) in eyes.enumerated() {
            eye.scale = [1, blinking ? 0.12 : 1.15, 0.6]
            pupils[i].isEnabled = !blinking
        }
    }
}
