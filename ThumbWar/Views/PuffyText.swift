//
//  PuffyText.swift
//  ThumbWar
//
//  Inflated, toy-like lettering: a dark extruded base, a thick white rim,
//  a gradient face and a glossy highlight on top.
//

import SwiftUI

struct PuffyText: View {
    let text: String
    var size: CGFloat = 64
    var color: Color = .orange

    private var font: Font { .system(size: size, weight: .black, design: .rounded) }
    private var rim: CGFloat { max(2, size / 14) }
    private var depth: Int { max(3, Int(size / 10)) }

    var body: some View {
        ZStack {
            // Extruded "side" of the letters.
            ForEach(0..<depth, id: \.self) { i in
                outline(CGFloat(i + 1) * 1.2)
                    .foregroundStyle(color.mix(with: .black, by: 0.5))
            }
            // Thick white rim.
            outline(0).foregroundStyle(.white)
            // Gradient face.
            Text(text).font(font)
                .foregroundStyle(LinearGradient(colors: [color.mix(with: .white, by: 0.4), color],
                                                startPoint: .top, endPoint: .bottom))
            // Glossy highlight on the upper half.
            Text(text).font(font)
                .foregroundStyle(.white.opacity(0.45))
                .mask(LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .clear, location: 0.45)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .multilineTextAlignment(.center)
        .fixedSize()
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: size / 10, y: size / 14)
        .accessibilityElement()
        .accessibilityLabel(text)
    }

    /// The text stamped around a circle of radius `rim`, shifted down by `drop`.
    private func outline(_ drop: CGFloat) -> some View {
        ZStack {
            ForEach(0..<12, id: \.self) { k in
                let a = Double(k) / 12 * 2 * .pi
                Text(text).font(font)
                    .offset(x: cos(a) * rim, y: sin(a) * rim + drop)
            }
        }
    }
}

/// PuffyText that bounces in when it appears.
struct PuffyPop: View {
    let text: String
    var size: CGFloat = 96
    var color: Color = .orange
    @State private var shown = false

    var body: some View {
        PuffyText(text: text, size: size, color: color)
            .scaleEffect(shown ? 1 : 0.2)
            .rotationEffect(.degrees(shown ? 0 : -14))
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(.spring(duration: 0.4, bounce: 0.6)) { shown = true }
            }
    }
}

#Preview {
    VStack(spacing: 30) {
        PuffyText(text: "THUMBEST WAR!", size: 80, color: .orange)
        PuffyText(text: "1", size: 120, color: .blue)
    }
    .padding()
    .background(Color.yellow.opacity(0.3))
}
