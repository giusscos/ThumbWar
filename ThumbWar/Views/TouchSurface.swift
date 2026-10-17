//
//  TouchSurface.swift
//  ThumbWar
//
//  Multi-touch input. Each finger is assigned to a side when it lands, so two
//  players can share one screen. Drag moves the thumb, lifting the finger slams.
//

import SwiftUI
import UIKit

struct TouchSurface: UIViewRepresentable {
    var sideForLocation: (CGPoint, CGSize) -> Side?
    var began: (Side) -> Void
    var moved: (Side, CGPoint) -> Void
    var ended: (Side) -> Void

    func makeUIView(context: Context) -> TouchView {
        let view = TouchView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: TouchView, context: Context) {
        view.surface = self
    }

    final class TouchView: UIView {
        var surface: TouchSurface?
        private var owners: [ObjectIdentifier: Side] = [:]

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let surface else { return }
            for touch in touches {
                // One finger per side: ignore extra fingers on a side that is already held.
                guard let side = surface.sideForLocation(touch.location(in: self), bounds.size),
                      !owners.values.contains(side) else { continue }
                owners[ObjectIdentifier(touch)] = side
                surface.began(side)
            }
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            guard let surface else { return }
            for touch in touches {
                guard let side = owners[ObjectIdentifier(touch)] else { continue }
                let now = touch.location(in: self), before = touch.previousLocation(in: self)
                surface.moved(side, CGPoint(x: now.x - before.x, y: now.y - before.y))
            }
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            finish(touches)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            finish(touches)
        }

        private func finish(_ touches: Set<UITouch>) {
            for touch in touches {
                if let side = owners.removeValue(forKey: ObjectIdentifier(touch)) {
                    surface?.ended(side)
                }
            }
        }
    }
}
