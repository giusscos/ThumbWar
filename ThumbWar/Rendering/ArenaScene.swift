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

@MainActor
final class ArenaScene {
    let root = Entity()
    let cameraPosition: SIMD3<Float> = [0, 0.36, 0.46]
    private var thumbs: [ThumbEntity] = []
    private var updateSubscription: EventSubscription?

    func build(in content: RealityViewCameraContent, game: ThumbWarGame) throws {
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
        camera.camera.fieldOfViewInDegrees = 34
        camera.look(at: [0, 0.095, 0], from: cameraPosition, relativeTo: nil)
        root.addChild(camera)

        content.add(root)
        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self, weak game] event in
            guard let self, let game else { return }
            let dt = Float(event.deltaTime)
            game.update(dt: dt)
            self.sync(game: game, dt: dt)
        }
        sync(game: game, dt: 0)
    }

    private func sync(game: ThumbWarGame, dt: Float) {
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
        switch game.stage {
        case .roundOver(let winner), .matchOver(let winner):
            return winner == side ? .happy : .worried
        case .pinned(let pinner):
            return pinner == side ? .happy : .worried
        case .menu, .chant:
            return .happy
        case .fight:
            return game.thumb(side).phase == .down ? .worried : .fierce
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
