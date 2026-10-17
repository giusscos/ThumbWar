//
//  GameFeedback.swift
//  ThumbWar
//
//  Turns game events into sounds and haptics, honoring the settings.
//

import AVFoundation
import UIKit

@MainActor
final class GameFeedback {
    private let settings: GameSettings
    private var players: [String: [AVAudioPlayer]] = [:]
    private let light = UIImpactFeedbackGenerator(style: .soft)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notify = UINotificationFeedbackGenerator()

    /// A few copies per sound so rapid repeats (mashing, ticks) can overlap.
    private static let sounds: [String: Int] = [
        "chant_1": 1, "chant_2": 1, "chant_3": 1, "chant_go": 1,
        "slam": 2, "jump": 2, "land": 2, "bump": 3, "pin": 1, "tick": 2, "tick_high": 2,
        "mash": 6, "escape": 1, "tired": 2, "point": 1, "win": 1, "lose": 1, "draw": 1, "ui_tap": 2,
    ]

    init(settings: GameSettings) {
        self.settings = settings
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        for (name, copies) in Self.sounds {
            guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { continue }
            players[name] = (0..<copies).compactMap { _ in
                let p = try? AVAudioPlayer(contentsOf: url)
                p?.enableRate = true
                p?.prepareToPlay()
                return p
            }
        }
    }

    func play(_ name: String, volume: Float = 1, pitchJitter: Float = 0) {
        guard settings.soundOn, let pool = players[name] else { return }
        let player = pool.first { !$0.isPlaying } ?? pool[0]
        player.currentTime = 0
        player.volume = volume
        player.rate = 1 + .random(in: -pitchJitter...pitchJitter)
        player.play()
    }

    func handle(_ event: GameEvent, mode: ThumbWarGame.Mode) {
        switch event {
        case .chantBeat(let beat):
            play(beat < 3 ? "chant_\(beat + 1)" : "chant_go")
            haptic { beat < 3 ? self.light.impactOccurred(intensity: 0.7) : self.heavy.impactOccurred() }
        case .slam:
            play("slam", volume: 0.7, pitchJitter: 0.08)
        case .lunge:
            play("jump", pitchJitter: 0.08)
            haptic { self.light.impactOccurred(intensity: 0.8) }
        case .land:
            play("land", pitchJitter: 0.1)
            haptic { self.light.impactOccurred() }
        case .tired:
            play("tired", pitchJitter: 0.05)
            haptic { self.notify.notificationOccurred(.warning) }
        case .bump(let speed):
            play("bump", volume: min(1, 0.4 + speed * 0.5), pitchJitter: 0.12)
            haptic { self.heavy.impactOccurred(intensity: CGFloat(min(1, speed))) }
        case .pin:
            play("pin")
            haptic { self.heavy.impactOccurred() }
        case .pinTick:
            play("tick")
            haptic { self.light.impactOccurred(intensity: 0.5) }
        case .mash:
            play("mash", volume: 0.6, pitchJitter: 0.15)
            haptic { self.light.impactOccurred(intensity: 0.4) }
        case .escape:
            play("escape")
            haptic { self.notify.notificationOccurred(.warning) }
        case .point:
            play("point")
            haptic { self.notify.notificationOccurred(.success) }
        case .timeTick:
            play("tick_high", volume: 0.8)
        case .matchOver(let winner):
            switch (winner, mode) {
            case (nil, _): play("draw")
            case (.right?, .vsCPU): play("lose")
            default: play("win")
            }
            haptic { self.notify.notificationOccurred(winner == nil ? .warning : .success) }
        }
    }

    func tap() {
        play("ui_tap", volume: 0.6)
        haptic { self.light.impactOccurred(intensity: 0.5) }
    }

    private func haptic(_ body: () -> Void) {
        if settings.hapticsOn { body() }
    }
}
