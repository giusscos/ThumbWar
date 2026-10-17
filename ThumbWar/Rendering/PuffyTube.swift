//
//  PuffyTube.swift
//  ThumbWar
//
//  A soft, rounded tube swept along a cubic Bézier and capped with a dome.
//  The vertex buffer is rewritten every frame so the thumb can bend and squish.
//

import Metal
import RealityKit
import simd

struct BezierCurve {
    var p0, p1, p2, p3: SIMD3<Float>

    func point(_ t: Float) -> SIMD3<Float> {
        let u = 1 - t
        return u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3
    }

    func tangent(_ t: Float) -> SIMD3<Float> {
        let u = 1 - t
        let d = 3 * u * u * (p1 - p0) + 6 * u * t * (p2 - p1) + 3 * t * t * (p3 - p2)
        return length(d) > 1e-6 ? normalize(d) : [0, 1, 0]
    }
}

final class PuffyTube {
    private struct Vertex {
        var position: SIMD3<Float>
        var normal: SIMD3<Float>
    }

    private let rings = 28
    private let capRings = 8
    private let segments = 24
    private let mesh: LowLevelMesh
    let resource: MeshResource

    init() throws {
        let ringCount = rings + capRings
        var descriptor = LowLevelMesh.Descriptor()
        descriptor.vertexAttributes = [
            .init(semantic: .position, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.position)!),
            .init(semantic: .normal, format: .float3, offset: MemoryLayout<Vertex>.offset(of: \.normal)!),
        ]
        descriptor.vertexLayouts = [.init(bufferIndex: 0, bufferStride: MemoryLayout<Vertex>.stride)]
        descriptor.vertexCapacity = ringCount * segments
        descriptor.indexCapacity = (ringCount - 1) * segments * 6
        descriptor.indexType = .uint32
        mesh = try LowLevelMesh(descriptor: descriptor)

        let segs = segments
        mesh.withUnsafeMutableIndices { raw in
            let indices = raw.bindMemory(to: UInt32.self)
            var k = 0
            for i in 0..<(ringCount - 1) {
                for j in 0..<segs {
                    let a = UInt32(i * segs + j)
                    let b = UInt32(i * segs + (j + 1) % segs)
                    let c = UInt32((i + 1) * segs + j)
                    let d = UInt32((i + 1) * segs + (j + 1) % segs)
                    indices[k] = a; indices[k + 1] = b; indices[k + 2] = c
                    indices[k + 3] = b; indices[k + 4] = d; indices[k + 5] = c
                    k += 6
                }
            }
        }
        resource = try MeshResource(from: mesh)
    }

    /// Radius along the thumb: slim at the knuckle, chubby near the tip.
    static func radius(at s: Float, base: Float) -> Float {
        base * (0.86 + 0.26 * s * s)
    }

    /// Rebuilds the vertices. `squash` > 1 fattens the tip (e.g. when pressed flat).
    func update(curve: BezierCurve, baseRadius: Float, squash: Float = 1) {
        let segs = segments, ringN = rings, capN = capRings
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        mesh.withUnsafeMutableBytes(bufferIndex: 0) { raw in
            let verts = raw.bindMemory(to: Vertex.self)

            // Parallel-transport frames so the tube never twists.
            var t = curve.tangent(0)
            var n = abs(t.z) < 0.9 ? normalize(cross(t, [0, 0, 1])) : normalize(cross(t, [1, 0, 0]))
            var center = curve.point(0)
            var r = Self.radius(at: 0, base: baseRadius)

            func writeRing(_ ring: Int, center: SIMD3<Float>, radius: Float, axis: SIMD3<Float>,
                           normal n: SIMD3<Float>, capAngle: Float) {
                let b = cross(axis, n)
                for j in 0..<segs {
                    let theta = Float(j) / Float(segs) * 2 * .pi
                    let radial = cos(theta) * n + sin(theta) * b
                    let p = center + radial * radius
                    let normal = normalize(radial * cos(capAngle) + axis * sin(capAngle))
                    verts[ring * segs + j] = Vertex(position: p, normal: normal)
                    lo = simd_min(lo, p)
                    hi = simd_max(hi, p)
                }
            }

            for i in 0..<ringN {
                let s = Float(i) / Float(ringN - 1)
                let newT = curve.tangent(s)
                n = normalize(n - dot(n, newT) * newT)
                t = newT
                center = curve.point(s)
                let tipBlend = max(0, (s - 0.6) / 0.4)
                r = Self.radius(at: s, base: baseRadius) * (1 + (squash - 1) * tipBlend)
                writeRing(i, center: center, radius: r, axis: t, normal: n, capAngle: 0)
            }

            // Dome cap over the tip.
            for k in 1...capN {
                let phi = Float(k) / Float(capN) * .pi / 2
                let capCenter = center + t * r * sin(phi) / squash.squareRoot()
                writeRing(ringN + k - 1, center: capCenter, radius: max(r * cos(phi), 0.0001),
                          axis: t, normal: n, capAngle: phi)
            }
        }

        let indexCount = (rings + capRings - 1) * segments * 6
        mesh.parts.replaceAll([
            LowLevelMesh.Part(indexCount: indexCount, topology: .triangle, bounds: BoundingBox(min: lo, max: hi))
        ])
    }
}
