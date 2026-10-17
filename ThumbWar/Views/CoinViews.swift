//
//  CoinViews.swift
//  ThumbWar
//
//  Coins, stars and the achievement toast, in the puffy style.
//

import SwiftUI

/// A chunky gold coin with a thumbs-up stamped on it.
struct CoinIcon: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.85, green: 0.5, blue: 0.05))
                .offset(y: size * 0.07)
            Circle()
                .fill(LinearGradient(colors: [Color(red: 1, green: 0.9, blue: 0.4), Color(red: 1, green: 0.7, blue: 0.1)],
                                     startPoint: .top, endPoint: .bottom))
            Circle()
                .strokeBorder(Color(red: 0.95, green: 0.6, blue: 0.08), lineWidth: size * 0.1)
            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: size * 0.46, weight: .black))
                .foregroundStyle(Color(red: 0.88, green: 0.55, blue: 0.05))
        }
        .frame(width: size, height: size)
        .accessibilityLabel("coins")
    }
}

/// The player's coin balance.
struct CoinPill: View {
    let coins: Int

    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: 22)
            Text("\(coins)")
                .font(.system(.headline, design: .rounded, weight: .black))
                .monospacedDigit()
                .contentTransition(.numericText())
                .animation(.spring, value: coins)
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(PuffyPalette.ink)
        .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
        .background(PuffySurface(shape: Capsule(), color: .white, depth: 4))
        .padding(.bottom, 4)
    }
}

struct StarIcon: View {
    let filled: Bool
    var size: CGFloat = 16

    var body: some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: size, weight: .black))
            .foregroundStyle(filled ? Color.yellow : PuffyPalette.ink.opacity(0.3))
            .shadow(color: filled ? Color.orange.opacity(0.8) : .clear, radius: 0, y: size * 0.08)
    }
}

/// "★ 12/60" for the Thumb Tour.
struct StarPill: View {
    let stars: Int
    let total: Int

    var body: some View {
        HStack(spacing: 5) {
            StarIcon(filled: true, size: 17)
            Text("\(stars)/\(total)")
                .font(.system(.headline, design: .rounded, weight: .black))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
        }
        .foregroundStyle(PuffyPalette.ink)
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(PuffySurface(shape: Capsule(), color: .white, depth: 4))
        .padding(.bottom, 4)
    }
}

/// Achievement announcements sliding in from the top.
struct ToastStack: View {
    let toasts: [Toast]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(toasts) { toast in
                HStack(spacing: 10) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.yellow)
                        .shadow(color: .orange, radius: 0, y: 1.5)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Achievement")
                            .font(.system(.caption2, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(toast.title)
                            .font(.system(.headline, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                    }
                    if toast.coins > 0 {
                        HStack(spacing: 4) {
                            Text("+\(toast.coins)")
                                .font(.system(.headline, design: .rounded, weight: .black))
                                .foregroundStyle(.yellow)
                            CoinIcon(size: 20)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 9)
                .background(PuffySurface(shape: Capsule(), color: .purple, depth: 5))
                .padding(.bottom, 5)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4, bounce: 0.4), value: toasts)
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, 10)
        .allowsHitTesting(false)
    }
}
