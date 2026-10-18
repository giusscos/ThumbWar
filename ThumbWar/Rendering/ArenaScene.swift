//
//  ArenaScene.swift
//  ThumbWar
//
//  Builds the 3D set (mat, clasped fists, lights, camera) and keeps the
//  thumb entities in sync with the simulation every frame.
//

import RealityKit
import SwiftUI
import UIKit

/// Where a view looks at the arena from. Also maps screen drags to world
/// movement so "drag right" always moves the thumb right on that screen.
struct CameraRig: Equatable {
    var position: SIMD3<Float>
    var target: SIMD3<Float>
    var fov: Float
    var horizontalFOV = false
    /// Rolled 180 degrees, for the player sitting across the top of the phone.
    var flipped = false

    func flipped(_ on: Bool) -> CameraRig {
        var rig = self
        rig.flipped = on
        return rig
    }

    /// Side-on view used in landscape.
    static let front = CameraRig(position: [0, 0.36, 0.46], target: [0, 0.095, 0], fov: 34)
    /// Side-on view framed for a tall screen.
    static let frontPortrait = CameraRig(position: [0, 0.34, 0.5], target: [0, 0.11, 0], fov: 46, horizontalFOV: true)

    /// Over-the-shoulder view from one player's side of the fists.
    /// `fov` is horizontal so the thumbs fill the width of any tall screen.
    static func behind(_ side: Side, fov: Float = 60) -> CameraRig {
        let s: Float = side == .left ? 1 : -1
        return CameraRig(position: [-0.19 * s, 0.25, 0.15 * s], target: [0.012 * s, 0.128, 0.004 * s], fov: fov, horizontalFOV: true)
    }

    /// Close-up on one thumb for the Locker preview.
    static func locker(_ side: Side) -> CameraRig {
        let x = Arena.startTargets[side.rawValue].x
        return CameraRig(position: [x * 0.7, 0.215, 0.2], target: [x, 0.158, 0], fov: 34)
    }

    #if DEBUG
    /// Square close-up of both thumbs for rendering the app icon (`-iconShot`).
    /// `-iconCam "px,py,pz,tx,ty,tz,fov"` overrides it while framing.
    static var icon: CameraRig {
        let v = (UserDefaults.standard.string(forKey: "iconCam") ?? "")
            .split(separator: ",").compactMap { Float($0.trimmingCharacters(in: .whitespaces)) }
        guard v.count == 7 else { return CameraRig(position: [0, 0.2, 0.2], target: [0, 0.14, 0], fov: 32) }
        return CameraRig(position: [v[0], v[1], v[2]], target: [v[3], v[4], v[5]], fov: v[6])
    }
    #endif

    /// Screen drag in points (y down) to world XZ meters.
    func worldDelta(dx: Float, dy: Float, scale: Float) -> SIMD2<Float> {
        var forward = target - position
        forward.y = 0
        forward = normalize(forward)
        let right = SIMD3<Float>(-forward.z, 0, forward.x)
        let w = right * dx - forward * dy
        return SIMD2(w.x, w.z) * scale * (flipped ? -1 : 1)
    }
}

@MainActor
final class ArenaScene {
    let root = Entity()
    let rig: CameraRig
    /// Only one scene per screen advances the simulation; the others just draw it.
    let drivesSimulation: Bool
    private var cameraPosition: SIMD3<Float> { rig.position }
    private var thumbs: [ThumbEntity] = []
    private var settings: GameSettings?
    private var updateSubscription: EventSubscription?
    private var frame = 0

    init(rig: CameraRig, drivesSimulation: Bool = true) {
        self.rig = rig
        self.drivesSimulation = drivesSimulation
    }

    func stop() {
        updateSubscription?.cancel()
        updateSubscription = nil
    }

    func build(in content: RealityViewCameraContent, game: ThumbWarGame, settings: GameSettings) throws {
        self.settings = settings
        root.addChild(makeBackdrop())
        root.addChild(makeFists())

        thumbs = try Side.allCases.map { try ThumbEntity(side: $0) }
        thumbs.forEach { root.addChild($0) }

        let sun = DirectionalLight()
        sun.light.intensity = 1400
        sun.light.color = UIColor(red: 1, green: 0.96, blue: 0.9, alpha: 1)
        sun.shadow = DirectionalLightComponent.Shadow(maximumDistance: 1.2, depthBias: 2)
        sun.look(at: [0, 0.08, 0], from: [-0.25, 0.6, 0.35], relativeTo: nil)
        root.addChild(sun)

        let fill = PointLight()
        fill.light.intensity = 500
        fill.light.attenuationRadius = 2
        fill.light.color = UIColor(red: 0.85, green: 0.9, blue: 1, alpha: 1)
        fill.position = [0.3, 0.25, 0.3]
        root.addChild(fill)

        let rim = PointLight()
        rim.light.intensity = 1200
        rim.light.attenuationRadius = 1
        rim.light.color = UIColor(red: 1, green: 0.85, blue: 0.75, alpha: 1)
        rim.position = [0, 0.3, -0.25]
        root.addChild(rim)

        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = rig.fov
        camera.camera.fieldOfViewOrientation = rig.horizontalFOV ? .horizontal : .vertical
        camera.look(at: rig.target, from: rig.position, upVector: rig.flipped ? [0, -1, 0] : [0, 1, 0], relativeTo: nil)
        root.addChild(camera)

        content.add(root)
        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self, weak game] event in
            guard let self, let game else { return }
            let dt = Float(event.deltaTime)
            if self.drivesSimulation { game.update(dt: dt) }
            self.sync(game: game, dt: dt)
            if self.frame % 60 == 0 { Self.presentWithoutTransaction() }
            self.frame += 1
        }
        sync(game: game, dt: 0)
    }

    /// RealityKit turns on `presentsWithTransaction` for a RealityView that doesn't
    /// fill the window (the Locker preview, the icon shot, a split-screen half).
    /// With a second RealityView on screen that deadlocks: all views share one
    /// render thread, the main thread waits on it to commit a frame, and it waits
    /// for a drawable this layer only gives back once the main thread commits its
    /// transaction. `nextDrawable` times out after a second, so every view drops to
    /// about 1 fps for as long as it lasts, and the frames drawn in between lose
    /// the LowLevelMesh thumbs (just the face, hat and a flat headband show).
    /// Presenting straight away avoids it. Rechecked about once a second so
    /// views that appear later are covered too.
    private static func presentWithoutTransaction() {
        func visit(_ layer: CALayer) {
            if let metal = layer as? CAMetalLayer, metal.presentsWithTransaction {
                metal.presentsWithTransaction = false
            }
            layer.sublayers?.forEach(visit)
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { visit($0.layer) }
        }
    }

    private func sync(game: ThumbWarGame, dt: Float) {
        // Dress the thumbs once the models are loaded, and whenever the loadout changes.
        var dress = settings != nil
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-iconShot") { dress = false }
        #endif
        if dress, let settings {
            for side in Side.allCases {
                let want = settings.effectiveLoadout(side)
                guard thumbs[side.rawValue].wearing != want else { continue }
                if AccessoryLibrary.shared.isReady(want) {
                    thumbs[side.rawValue].wear(want)
                } else {
                    AccessoryLibrary.shared.load(want.ids)
                }
            }
        }
        for side in Side.allCases {
            let me = game.thumb(side)
            let them = game.thumb(side.opponent)
            thumbs[side.rawValue].update(
                state: me,
                opponentTip: them.tip,
                cameraPosition: cameraPosition,
                mood: mood(for: side, in: game),
                dt: dt
            )
        }
    }

    private func mood(for side: Side, in game: ThumbWarGame) -> ThumbEntity.Mood {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-iconShot"), game.stage == .menu { return .fierce }
        #endif
        switch game.stage {
        case .roundOver(let winner):
            return winner == side ? .happy : .worried
        case .matchOver(let winner):
            return winner == nil || winner == side ? .happy : .worried
        case .pinned(let pinner):
            return pinner == side ? .happy : .worried
        case .menu, .chant:
            return .happy
        case .fight:
            let thumb = game.thumb(side)
            if thumb.isHooking { return .fierce }
            return thumb.phase == .down || thumb.isTired ? .worried : .fierce
        }
    }

    // MARK: - Set pieces

    private func makeBackdrop() -> Entity {
        let set = Entity()

        var sky = UnlitMaterial(color: UIColor(red: 0.55, green: 0.82, blue: 1.0, alpha: 1))
        sky.faceCulling = .front
        let skyDome = ModelEntity(mesh: .generateSphere(radius: 4), materials: [sky])
        set.addChild(skyDome)

        let floor = ModelEntity(mesh: .generatePlane(width: 3, depth: 3),
                                materials: [PuffyMaterials.matte(UIColor(red: 1.0, green: 0.86, blue: 0.62, alpha: 1))])
        set.addChild(floor)

        // Wrestling mat with a soft rim.
        let mat = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.24),
                              materials: [PuffyMaterials.matte(UIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1))])
        mat.position.y = 0.006
        set.addChild(mat)
        let rimRing = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.255),
                                  materials: [PuffyMaterials.glossy(UIColor(red: 1.0, green: 0.78, blue: 0.2, alpha: 1), roughness: 0.5)])
        rimRing.position.y = 0.004 - 0.001
        set.addChild(rimRing)
        return set
    }

    /// Two chubby fists gripping each other, forearms reaching out to each side.
    private func makeFists() -> Entity {
        let fists = Entity()
        let skin = PuffyMaterials.skin()

        for side in Side.allCases {
            let x: Float = side == .left ? -1 : 1

            let palm = ModelEntity(mesh: .generateSphere(radius: 1), materials: [skin])
            palm.position = [x * 0.042, 0.048, -0.004]
            palm.scale = [0.05, 0.042, 0.048]
            fists.addChild(palm)

            // Curled fingers: a row of soft knuckles on the front of each fist.
            for k in 0..<4 {
                let finger = ModelEntity(mesh: .generateSphere(radius: 0.0155), materials: [skin])
                let fx = x * (0.012 + Float(k) * 0.0175)
                finger.position = [fx, 0.04 - Float(k) * 0.002, 0.04]
                finger.scale = [1, 1.25, 1]
                fists.addChild(finger)
            }

            let forearm = ModelEntity(mesh: .generateCylinder(height: 0.5, radius: 0.034), materials: [skin])
            forearm.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            forearm.position = [x * 0.32, 0.042, -0.01]
            fists.addChild(forearm)

            let cuff = ModelEntity(mesh: .generateCylinder(height: 0.03, radius: 0.038),
                                   materials: [PuffyMaterials.glossy(PuffyMaterials.teamColor(side), roughness: 0.45)])
            cuff.orientation = forearm.orientation
            cuff.position = [x * 0.11, 0.042, -0.01]
            fists.addChild(cuff)
        }
        return fists
    }
}
