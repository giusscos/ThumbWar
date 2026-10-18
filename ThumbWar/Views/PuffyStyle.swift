//
//  PuffyStyle.swift
//  ThumbWar
//
//  The chunky toy look shared by every control: a darker base underneath,
//  a gradient face that sinks when pressed, and a soft gloss on top.
//

import SwiftUI

enum PuffyPalette {
    static let cream = Color(red: 1.0, green: 0.96, blue: 0.86)
    static let creamDeep = Color(red: 1.0, green: 0.88, blue: 0.66)
    static let ink = Color(red: 0.42, green: 0.25, blue: 0.13)
    static let blue = Color(PuffyMaterials.teamColor(.left))
    static let red = Color(PuffyMaterials.teamColor(.right))

    static func team(_ side: Side) -> Color { side == .left ? blue : red }
}

struct PuffySurface<S: Shape>: View {
    let shape: S
    let color: Color
    var pressed = false
    var depth: CGFloat = 6

    var body: some View {
        ZStack {
            shape.fill(color.mix(with: .black, by: 0.32))
                .offset(y: depth)
            ZStack {
                shape.fill(LinearGradient(colors: [color.mix(with: .white, by: 0.25), color],
                                          startPoint: .top, endPoint: .bottom))
                shape.fill(LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0)],
                                          startPoint: .top, endPoint: .center))
                    .padding(.horizontal, 6)
                    .padding(.top, 3)
                    .padding(.bottom, 8)
            }
            .offset(y: pressed ? depth * 0.75 : 0)
        }
    }
}

struct PuffyButtonStyle<S: Shape>: ButtonStyle {
    let color: Color
    let shape: S
    var textColor: Color = .white
    var depth: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .foregroundStyle(textColor)
            .offset(y: pressed ? depth * 0.75 : 0)
            .background(PuffySurface(shape: shape, color: color, pressed: pressed, depth: depth))
            .padding(.bottom, depth)
            .animation(.spring(duration: 0.14, bounce: 0.45), value: pressed)
    }
}

extension ButtonStyle where Self == PuffyButtonStyle<Capsule> {
    static func puffy(_ color: Color, text: Color = .white) -> Self {
        PuffyButtonStyle(color: color, shape: Capsule(), textColor: text)
    }
}

extension ButtonStyle where Self == PuffyButtonStyle<Circle> {
    static func puffyCircle(_ color: Color) -> Self {
        PuffyButtonStyle(color: color, shape: Circle(), depth: 4)
    }
}

/// A labeled capsule button in the puffy style.
struct PuffyButton: View {
    let title: String
    let color: Color
    var compact = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(compact ? .headline : .title3, design: .rounded, weight: .heavy))
                .shadow(color: .black.opacity(0.18), radius: 0, y: 1.5)
                .padding(.horizontal, compact ? 16 : 22)
                .padding(.vertical, compact ? 10 : 13)
        }
        .buttonStyle(.puffy(color))
    }
}

struct RoundIconButton: View {
    let systemName: String
    var color: Color = .orange
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .heavy))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.puffyCircle(color))
    }
}

/// A selectable chip for picking one option.
struct PuffyChip: View {
    let title: String
    var systemImage: String?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.system(.subheadline, design: .rounded, weight: .heavy))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.puffy(selected ? .orange : .white, text: selected ? .white : PuffyPalette.ink))
    }
}

/// Fires on touch-down so it can be mashed as fast as fingers allow,
/// and reports the release so holding it can mean something.
struct SlamButton: View {
    let side: Side
    let title: String
    let enabled: Bool
    var pulse = false
    var size: CGFloat = 96
    let action: () -> Void
    var release: () -> Void = {}
    @State private var pressed = false

    var body: some View {
        let depth: CGFloat = 8
        Text(title)
            .font(.system(size: size * 0.23, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.2), radius: 0, y: 2)
            .frame(width: size, height: size)
            .offset(y: pressed ? depth * 0.75 : 0)
            .background(PuffySurface(shape: Circle(), color: PuffyPalette.team(side), pressed: pressed, depth: depth))
            .padding(.bottom, depth)
            .scaleEffect(pulse && !pressed ? 1.06 : 1)
            .opacity(enabled ? 1 : 0.45)
            .animation(.spring(duration: 0.14, bounce: 0.5), value: pressed)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        pressed = true
                        action()
                    }
                    .onEnded { _ in
                        pressed = false
                        release()
                    }
            )
    }
}

/// A small white puffy capsule for hints and info lines floating over the arena.
struct PuffyTag<Content: View>: View {
    var compact = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .font(.system(compact ? .footnote : .subheadline, design: .rounded, weight: .heavy))
            .foregroundStyle(PuffyPalette.ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, compact ? 12 : 14).padding(.vertical, compact ? 5 : 7)
            .background(PuffySurface(shape: Capsule(), color: .white, depth: 4))
            .padding(.bottom, 4)
    }
}

/// Cream card with a thick white rim and a darker base, like a toy panel.
struct PuffyCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        content
            .background {
                ZStack {
                    shape.fill(PuffyPalette.creamDeep.mix(with: .black, by: 0.25)).offset(y: 8)
                    shape.fill(LinearGradient(colors: [PuffyPalette.cream, PuffyPalette.creamDeep],
                                              startPoint: .top, endPoint: .bottom))
                    shape.strokeBorder(.white, lineWidth: 4)
                }
            }
    }
}

/// Fades a scroll view's content out at its edges instead of cutting it off.
/// Matching content margins keep the first and last rows clear of the fade at rest.
struct ScrollEdgeFade: ViewModifier {
    var axis: Axis = .vertical
    var length: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .contentMargins(axis == .vertical ? .vertical : .horizontal, length, for: .scrollContent)
            .mask {
                let fadeIn = Gradient(colors: [.clear, .black])
                if axis == .vertical {
                    VStack(spacing: 0) {
                        LinearGradient(gradient: fadeIn, startPoint: .top, endPoint: .bottom).frame(height: length)
                        Rectangle()
                        LinearGradient(gradient: fadeIn, startPoint: .bottom, endPoint: .top).frame(height: length)
                    }
                } else {
                    HStack(spacing: 0) {
                        LinearGradient(gradient: fadeIn, startPoint: .leading, endPoint: .trailing).frame(width: length)
                        Rectangle()
                        LinearGradient(gradient: fadeIn, startPoint: .trailing, endPoint: .leading).frame(width: length)
                    }
                }
            }
    }
}

extension View {
    func scrollEdgeFade(_ axis: Axis = .vertical, length: CGFloat = 20) -> some View {
        modifier(ScrollEdgeFade(axis: axis, length: length))
    }
}
