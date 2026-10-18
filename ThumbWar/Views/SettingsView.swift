//
//  SettingsView.swift
//  ThumbWar
//
//  Settings as an in-game panel, in the same puffy style as the rest of the game.
//

import SwiftUI

struct SettingsView: View {
    @Bindable var settings: GameSettings
    let feedback: GameFeedback
    let onDone: () -> Void

    @Environment(Store.self) private var store

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture(perform: onDone)

            PuffyCard {
                VStack(spacing: 12) {
                    PuffyText(text: "Settings", size: 38, color: .purple)
                        .padding(.top, 4)

                    // Hug the content when it fits; scroll when the screen is short.
                    ViewThatFits(in: .vertical) {
                        options
                        ScrollView { options }
                            .scrollBounceBehavior(.basedOnSize)
                            .scrollEdgeFade()
                    }

                    PuffyButton(title: "Done", color: .green) {
                        feedback.tap()
                        onDone()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var options: some View {
                        VStack(alignment: .leading, spacing: 18) {
                            section("Slam with", footer: settings.slamControl == .lift
                                    ? "Drag to move, lift your finger to slam. Pinned? Wiggle to escape."
                                    : "Drag to move, tap SLAM. Hold SLAM to stay down as a hook: if they pin your hook, mash to flip them!") {
                                HStack(spacing: 10) {
                                    ForEach(SlamControl.allCases) { option in
                                        PuffyChip(title: option.title,
                                                  systemImage: option == .lift ? "hand.point.up.fill" : "circle.circle.fill",
                                                  selected: settings.slamControl == option) {
                                            feedback.tap()
                                            settings.slamControl = option
                                        }
                                    }
                                }
                            }

                            section("Match", footer: settings.matchLength == .firstTo3
                                    ? "First thumb to win 3 pins takes the match."
                                    : "Most pins at the buzzer wins, same score is a draw. A pin in progress plays out in overtime.") {
                                HStack(spacing: 8) {
                                    ForEach(MatchLength.allCases) { option in
                                        PuffyChip(title: option.title, selected: settings.matchLength == option) {
                                            feedback.tap()
                                            settings.matchLength = option
                                        }
                                    }
                                }
                            }

                            section("CPU level", footer: settings.cpuLevel == .hard
                                    ? "Fast, dodges almost everything, and sets hooks."
                                    : (settings.cpuLevel == .easy ? "Slow and forgiving. Good for learning." : "A fair fight.")) {
                                HStack(spacing: 8) {
                                    ForEach(CPULevel.allCases) { level in
                                        PuffyChip(title: level.title, selected: settings.cpuLevel == level) {
                                            feedback.tap()
                                            settings.cpuLevel = level
                                        }
                                    }
                                }
                            }

                            section("Feedback", footer: nil) {
                                HStack(spacing: 10) {
                                    PuffyChip(title: settings.soundOn ? "Sound on" : "Sound off",
                                              systemImage: settings.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                              selected: settings.soundOn) {
                                        settings.soundOn.toggle()
                                        feedback.tap()
                                    }
                                    PuffyChip(title: settings.hapticsOn ? "Haptics on" : "Haptics off",
                                              systemImage: settings.hapticsOn ? "iphone.radiowaves.left.and.right" : "iphone.slash",
                                              selected: settings.hapticsOn) {
                                        settings.hapticsOn.toggle()
                                        feedback.tap()
                                    }
                                }
                            }

                            section("Purchases", footer: store.restoreMessage
                                    ?? "Bought premium items on another device, or reinstalled? Get them back here.") {
                                Button {
                                    feedback.tap()
                                    Task { await store.restore() }
                                } label: {
                                    HStack(spacing: 6) {
                                        if store.isRestoring {
                                            ProgressView().tint(.white)
                                        } else {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                        Text("Restore Purchases")
                                    }
                                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                    .padding(.horizontal, 16).padding(.vertical, 9)
                                }
                                .buttonStyle(.puffy(.pink))
                                .disabled(store.isRestoring)
                            }

                            section("About", footer: "ThumbestWar collects no data. No accounts, no ads, no tracking.") {
                                HStack(spacing: 10) {
                                    linkChip("Privacy Policy", systemImage: "hand.raised.fill",
                                             url: "https://giusscos.com/work/thumbestwar/privacy/")
                                    linkChip("Support", systemImage: "questionmark.bubble.fill",
                                             url: "https://giusscos.com/work/thumbestwar/support/")
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
    }

    /// Opens a page on giusscos.com in the browser.
    private func linkChip(_ title: String, systemImage: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: systemImage)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.puffy(.white, text: PuffyPalette.ink))
        .simultaneousGesture(TapGesture().onEnded { feedback.tap() })
    }

    private func section(_ title: String, footer: String?, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(.footnote, design: .rounded, weight: .black))
                .foregroundStyle(PuffyPalette.ink.opacity(0.75))
            content()
            if let footer {
                Text(footer)
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(PuffyPalette.ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
