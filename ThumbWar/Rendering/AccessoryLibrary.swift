//
//  AccessoryLibrary.swift
//  ThumbWar
//
//  Loads accessory models on demand (once each) and hands out clones.
//

import Foundation
import RealityKit

@MainActor
final class AccessoryLibrary {
    static let shared = AccessoryLibrary()

    private var prototypes: [String: Entity] = [:]
    private var pending: Set<String> = []

    /// Starts loading any of these models that aren't loaded yet.
    func load(_ ids: [String]) {
        for id in ids where prototypes[id] == nil && !pending.contains(id) {
            pending.insert(id)
            Task {
                if let entity = try? await Entity(named: id, in: .main) {
                    prototypes[id] = entity
                }
                pending.remove(id)
            }
        }
    }

    func loadAll() {
        load(Accessory.all.map(\.id))
    }

    func isReady(_ loadout: Loadout) -> Bool {
        loadout.ids.allSatisfy { prototypes[$0] != nil }
    }

    func make(_ id: String) -> Entity? {
        prototypes[id]?.clone(recursive: true)
    }
}
