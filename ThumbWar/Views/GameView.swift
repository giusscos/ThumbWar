//
//  GameView.swift
//  ThumbWar
//
//  Picks a layout for the screen shape:
//  - landscape: one side-on view, left/right halves of the screen per player
//  - portrait vs CPU: over-the-shoulder view, controls along the bottom
//  - portrait 2 players: split screen, each player gets their own camera and
//    controls; the top half is flipped for the player across the table
//

import RealityKit
import SwiftUI

struct GameView: View {
    @State private var game = ThumbWarGame()
    @State private var settings: GameSettings
    @State private var feedback: GameFeedback
    @State private var showSettings = false
    @State private var showLocker = false
    @State private var showTrophies = false
    @State private var career: Career
    @State private var store: Store
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = GameSettings()
        _settings = State(initialValue: settings)
        _feedback = State(initialValue: GameFeedback(settings: settings))
        let career = Career(profile: Profile(), gameCenter: GameCenter())
        _career = State(initialValue: career)
        _store = State(initialValue: Store(profile: career.profile))
    }

    var body: some View {
        GeometryReader { geo in
            let portrait = geo.size.height > geo.size.width
            ZStack {
                if !portrait {
                    landscape
                } else if game.mode == .twoPlayers && game.stage != .menu {
                    split(insets: geo.safeAreaInsets)
                } else {
                    portraitSingle
                }

                if game.stage == .menu {
                    MenuView(game: game, settings: settings, feedback: feedback,
                             showSettings: $showSettings, showLocker: $showLocker, showTrophies: $showTrophies)
                }
                if career.showTour {
                    TourView(game: game, settings: settings, feedback: feedback)
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                if showTrophies {
                    TrophiesView(feedback: feedback) { showTrophies = false }
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                if game.isPaused {
                    PauseMenu(game: game, settings: settings, feedback: feedback, showSettings: $showSettings)
                }
                if showLocker {
                    LockerView(game: game, settings: settings, feedback: feedback) { showLocker = false }
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
                if showSettings {
                    SettingsView(settings: settings, feedback: feedback) { showSettings = false }
                        .transition(.opacity.combined(with: .scale(scale: 0.92)))
                }
            }
            .animation(.spring(duration: 0.3, bounce: 0.3), value: showSettings)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: showLocker)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: showTrophies)
            .animation(.spring(duration: 0.3, bounce: 0.3), value: career.showTour)
            .overlay { ToastStack(toasts: career.toasts) }
            #if DEBUG
            .overlay {
                if ProcessInfo.processInfo.arguments.contains("-iconShot") {
                    // Icon render: a square of the arena pinned to the top, nothing else.
                    ZStack(alignment: .top) {
                        Color.black.ignoresSafeArea()
                        ArenaView(game: game, settings: settings, rig: .icon, drivesSimulation: false)
                            .frame(width: geo.size.width, height: geo.size.width)
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea()
                }
            }
            #endif
            // A fixed frame: an oversized banner can never widen the layout and shift the camera.
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .environment(career)
        .environment(store)
        .onAppear {
            settings.removeUnowned(career.profile.owns)
            store.onOwnedChange = { [career, settings] in
                settings.removeUnowned(career.profile.owns)
                career.checkAchievements()
            }
            store.start()
            AccessoryLibrary.shared.load(settings.loadouts.flatMap(\.ids))
            career.connect()
            game.onEvent = { [feedback, career, settings, weak game] event in
                guard let game else { return }
                feedback.handle(event, mode: game.mode)
                if case .matchOver(let winner) = event {
                    career.matchFinished(game: game, winner: winner, settings: settings)
                }
            }
            #if DEBUG
            if let forced = UserDefaults.standard.string(forKey: "debugOrientation"),
               let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                scene.requestGeometryUpdate(.iOS(interfaceOrientations: forced == "portrait" ? .portrait : .landscapeRight))
            }
            if ProcessInfo.processInfo.arguments.contains("-openSettings") { showSettings = true }
            if ProcessInfo.processInfo.arguments.contains("-openLocker") { showLocker = true }
            if ProcessInfo.processInfo.arguments.contains("-openTour") { career.showTour = true }
            if ProcessInfo.processInfo.arguments.contains("-openTrophies") { showTrophies = true }
            if ProcessInfo.processInfo.arguments.contains("-autostartCPU") {
                career.playQuick(.vsCPU, game: game, settings: settings)
            } else if ProcessInfo.processInfo.arguments.contains("-autostart2P") {
                career.playQuick(.twoPlayers, game: game, settings: settings)
            } else if let id = Int(UserDefaults.standard.string(forKey: "debugChallenge") ?? ""),
                      let challenge = Challenge.all.first(where: { $0.id == id }) {
                career.play(challenge, game: game, settings: settings)
            }
            #endif
        }
        .onChange(of: settings.slamControl, initial: true) { game.slamControl = settings.slamControl }
        .onChange(of: settings.cpuLevel, initial: true) { game.cpuLevel = settings.cpuLevel }
        .onChange(of: scenePhase) {
            if scenePhase != .active, game.isPlaying { game.isPaused = true }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: Layouts

    private var landscape: some View {
        let rig = CameraRig.front
        return ZStack {
            ArenaView(game: game, settings: settings, rig: rig).id("front")
                .ignoresSafeArea()
            touchSurface(rig: rig) { point, size in
                game.mode == .vsCPU || point.x < size.width / 2 ? .left : .right
            }
            if game.stage != .menu {
                LandscapeHUD(game: game, settings: settings, feedback: feedback)
            }
        }
    }

    private var portraitSingle: some View {
        let rig: CameraRig = game.stage == .menu ? .frontPortrait : .behind(.left)
        return ZStack {
            ArenaView(game: game, settings: settings, rig: rig).id(game.stage == .menu ? "menu" : "behind")
                .ignoresSafeArea()
            touchSurface(rig: rig) { _, _ in .left }
            if game.stage != .menu {
                PortraitHUD(game: game, settings: settings, feedback: feedback)
            }
        }
    }

    private func split(insets: EdgeInsets) -> some View {
        ZStack {
            VStack(spacing: 0) {
                // Each HUD sits by its player's screen edge: the top one by the front camera.
                // A punch-hole camera (iPhone Duo's outer display) isn't in the safe area,
                // so the top HUD always keeps at least 64pt clear of the edge.
                half(.right, flipped: true, edgeInset: max(insets.top, 64))
                Rectangle().fill(.white).frame(height: 4)
                half(.left, flipped: false, edgeInset: insets.bottom)
            }
            .ignoresSafeArea()

            // Shared clock and pause on the seam between the halves.
            HStack(spacing: 10) {
                if let seconds = game.secondsLeft {
                    TimerPill(seconds: seconds, overtime: game.isOvertime)
                }
                if game.isPlaying {
                    RoundIconButton(systemName: "pause.fill") {
                        feedback.tap()
                        game.isPaused = true
                    }
                }
            }
        }
    }

    /// `edgeInset` is the safe area at this half's outer screen edge, where its HUD sits.
    private func half(_ side: Side, flipped: Bool, edgeInset: CGFloat) -> some View {
        let rig = CameraRig.behind(side, fov: 58).flipped(flipped)
        return ZStack {
            ArenaView(game: game, settings: settings, rig: rig, drivesSimulation: side == .left).id("split-\(side)")
            touchSurface(rig: rig) { _, _ in side }
            PlayerHalfHUD(game: game, settings: settings, feedback: feedback, viewer: side)
                .padding(.top, 26)
                .padding(.bottom, max(26, edgeInset + 8))
                .padding(.horizontal, 18)
                .rotationEffect(.degrees(flipped ? 180 : 0))
        }
        .clipped()
    }

    private func touchSurface(rig: CameraRig, side: @escaping (CGPoint, CGSize) -> Side?) -> some View {
        TouchSurface(
            sideForLocation: side,
            began: { game.touchBegan($0) },
            moved: { s, d in
                game.touchMoved(s, delta: rig.worldDelta(dx: Float(d.x), dy: Float(d.y), scale: 0.0008))
            },
            ended: { game.touchEnded($0) }
        )
        .ignoresSafeArea()
    }
}

/// One RealityView looking at the arena through a camera rig.
struct ArenaView: View {
    let game: ThumbWarGame
    let settings: GameSettings
    let rig: CameraRig
    var drivesSimulation = true
    @State private var holder = Holder()

    final class Holder { var scene: ArenaScene? }

    var body: some View {
        RealityView { content in
            content.camera = .virtual
            let scene = ArenaScene(rig: rig, drivesSimulation: drivesSimulation)
            try? scene.build(in: content, game: game, settings: settings)
            holder.scene = scene
        }
        .onDisappear { holder.scene?.stop() }
    }
}
