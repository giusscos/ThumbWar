//
//  PuffyMaterials.swift
//  ThumbWar
//

import RealityKit
import UIKit

enum PuffyMaterials {
    /// Soft, toy-like skin: satin roughness, a light clear coat and a warm sheen
    /// that reads like light scattering through the surface.
    static func skin() -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: UIColor(red: 1.0, green: 0.78, blue: 0.62, alpha: 1))
        m.roughness = 0.55
        m.metallic = 0.0
        m.clearcoat = 0.35
        m.clearcoatRoughness = 0.45
        m.emissiveColor = .init(color: UIColor(red: 0.45, green: 0.12, blue: 0.06, alpha: 1))
        m.emissiveIntensity = 0.08
        m.faceCulling = .none
        return m
    }

    static func glossy(_ color: UIColor, roughness: Float = 0.25) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = 0.0
        m.clearcoat = 0.6
        m.clearcoatRoughness = 0.2
        return m
    }

    static func matte(_ color: UIColor) -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: color)
        m.roughness = 0.9
        m.metallic = 0.0
        return m
    }

    static func teamColor(_ side: Side) -> UIColor {
        side == .left
            ? UIColor(red: 0.20, green: 0.52, blue: 1.0, alpha: 1)
            : UIColor(red: 1.0, green: 0.32, blue: 0.30, alpha: 1)
    }
}
