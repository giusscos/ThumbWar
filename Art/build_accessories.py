"""Builds ThumbWar's wearable accessories in Blender, renders their thumbnails
and exports them as USDZ for RealityKit.

Run inside Blender (for example through the Blender MCP):

    exec(open("/Users/m1pro/Developer/ThumbWar/Art/build_accessories.py").read())
    build_all()            # or build("crown", "cap")
    render_thumbnails()    # writes ThumbWar/Accessories/thumb_<id>.png
    export_all()           # writes ThumbWar/Accessories/<id>.usdz

Head units: the thumb tip is a sphere of radius 1 at the origin, +Z is up and
the face looks toward -Y. The export converts this to Y-up with the face toward
+Z, which is how ThumbEntity attaches accessories to the tip.
"""

import os
from math import atan2, cos, pi, sin, tau

import bmesh
import bpy
from mathutils import Matrix, Vector

REPO = "/Users/m1pro/Developer/ThumbWar"
MODELS = f"{REPO}/ThumbWar/Accessories"
SCENE = "ThumbWarAccessories"
FRONT = 3 * pi / 2          # lathe angle that points at the face (-Y)
BACK_TILT = (-0.2, 0, 0)    # hats lean back so the brows stay visible


def scene():
    scn = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scn
    return scn


# --- Materials -------------------------------------------------------------------

PALETTE = {
    "gold": dict(rgb=(1.0, 0.7, 0.16), rough=0.25, metal=0.85, coat=0.3),
    "pearl": dict(rgb=(0.96, 0.93, 0.86), rough=0.2, coat=0.6),
    "velvet": dict(rgb=(0.62, 0.04, 0.12), rough=0.85, coat=0.0),
    "ruby": dict(rgb=(0.9, 0.05, 0.18), rough=0.08, coat=1.0),
    "sapphire": dict(rgb=(0.1, 0.3, 1.0), rough=0.08, coat=1.0),
    "emerald": dict(rgb=(0.05, 0.75, 0.35), rough=0.08, coat=1.0),
    "yellow": dict(rgb=(1.0, 0.78, 0.12), rough=0.5, coat=0.2),
    "orange": dict(rgb=(1.0, 0.48, 0.08), rough=0.5, coat=0.2),
    "cream": dict(rgb=(0.98, 0.95, 0.88), rough=0.6, coat=0.1),
    "pink": dict(rgb=(1.0, 0.42, 0.68), rough=0.45, coat=0.25),
    "cloth": dict(rgb=(0.97, 0.97, 0.95), rough=0.85, coat=0.0),
    "steel": dict(rgb=(0.68, 0.72, 0.78), rough=0.28, metal=0.75, coat=0.2),
    "bronze": dict(rgb=(0.72, 0.45, 0.2), rough=0.35, metal=0.7, coat=0.2),
    "bone": dict(rgb=(0.98, 0.93, 0.8), rough=0.45, coat=0.3),
    "black": dict(rgb=(0.05, 0.05, 0.07), rough=0.35, coat=0.5),
    "satin": dict(rgb=(0.92, 0.15, 0.22), rough=0.35, coat=0.4),
    "red": dict(rgb=(0.95, 0.18, 0.2), rough=0.4, coat=0.3),
    "blue": dict(rgb=(0.18, 0.48, 1.0), rough=0.4, coat=0.3),
    "green": dict(rgb=(0.2, 0.8, 0.35), rough=0.4, coat=0.3),
    "glassDark": dict(rgb=(0.02, 0.02, 0.04), rough=0.03, coat=1.0),
    "glassClear": dict(rgb=(0.8, 0.9, 1.0), rough=0.02, coat=1.0, alpha=0.25),
    "brown": dict(rgb=(0.32, 0.18, 0.08), rough=0.85),
    "tortoise": dict(rgb=(0.42, 0.2, 0.07), rough=0.3, coat=0.7),
    "felt": dict(rgb=(0.56, 0.34, 0.16), rough=0.8),
    "leather": dict(rgb=(0.25, 0.14, 0.07), rough=0.6, coat=0.1),
    "silver": dict(rgb=(0.85, 0.86, 0.9), rough=0.2, metal=0.9, coat=0.2),
    "wizard": dict(rgb=(0.16, 0.22, 0.7), rough=0.7, coat=0.05),
    "starGold": dict(rgb=(1.0, 0.82, 0.25), rough=0.3, metal=0.5, coat=0.4, emit=(1.0, 0.8, 0.3), strength=0.6),
    "knitRed": dict(rgb=(0.88, 0.16, 0.2), rough=0.9),
    "knitCream": dict(rgb=(0.96, 0.93, 0.85), rough=0.9),
    "fur": dict(rgb=(0.98, 0.97, 0.96), rough=0.9),
    "furPink": dict(rgb=(1.0, 0.66, 0.76), rough=0.8),
    "halo": dict(rgb=(1.0, 0.8, 0.3), rough=0.2, metal=0.6, coat=0.5, emit=(1.0, 0.78, 0.3), strength=0.45),
    "unicorn": dict(rgb=(1.0, 0.86, 0.55), rough=0.25, metal=0.45, coat=0.6),
    "maneP": dict(rgb=(1.0, 0.62, 0.82), rough=0.8),
    "maneL": dict(rgb=(0.72, 0.6, 1.0), rough=0.8),
    "maneM": dict(rgb=(0.5, 0.92, 0.8), rough=0.8),
    "phone": dict(rgb=(1.0, 0.38, 0.58), rough=0.3, coat=0.6),
    "white": dict(rgb=(0.97, 0.97, 0.97), rough=0.35, coat=0.5),
    "cushion": dict(rgb=(0.2, 0.2, 0.24), rough=0.7),
    "pirate": dict(rgb=(0.08, 0.07, 0.09), rough=0.6, coat=0.1),
    "clown": dict(rgb=(1.0, 0.08, 0.08), rough=0.12, coat=1.0),
    "heartGlass": dict(rgb=(1.0, 0.3, 0.55), rough=0.05, coat=1.0, alpha=0.85),
    "heartFrame": dict(rgb=(1.0, 0.2, 0.5), rough=0.3, coat=0.6),
    "witch": dict(rgb=(0.17, 0.09, 0.26), rough=0.75, coat=0.05),
    "witchBand": dict(rgb=(0.62, 0.25, 0.9), rough=0.45, coat=0.3),
    "pumpkin": dict(rgb=(1.0, 0.46, 0.05), rough=0.55, coat=0.25),
    "glow": dict(rgb=(0.3, 0.1, 0.0), rough=0.6, emit=(1.0, 0.72, 0.15), strength=4.0),
    "stem": dict(rgb=(0.36, 0.33, 0.12), rough=0.85),
    "leaf": dict(rgb=(0.3, 0.62, 0.18), rough=0.6, coat=0.2),
    "devil": dict(rgb=(0.9, 0.07, 0.1), rough=0.18, coat=1.0),
    "catBlack": dict(rgb=(0.07, 0.07, 0.09), rough=0.6, coat=0.2),
    "bandage": dict(rgb=(0.88, 0.82, 0.68), rough=0.95, coat=0.0),
    "frankHair": dict(rgb=(0.09, 0.1, 0.08), rough=0.9, coat=0.0),
    "scar": dict(rgb=(0.3, 0.08, 0.1), rough=0.8),
    "spider": dict(rgb=(0.06, 0.05, 0.09), rough=0.25, coat=0.8),
    "eyeWhite": dict(rgb=(1, 1, 1), rough=0.15, coat=0.5),
    "pupil": dict(rgb=(0.02, 0.02, 0.02), rough=0.1, coat=0.5),
    "fang": dict(rgb=(0.99, 0.98, 0.95), rough=0.15, coat=0.8),
    "witchNose": dict(rgb=(0.45, 0.74, 0.3), rough=0.6, coat=0.1),
    "wart": dict(rgb=(0.32, 0.55, 0.2), rough=0.7),
}


def M(key):
    spec = PALETTE[key]
    name = "TW_" + key
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    b = m.node_tree.nodes.get("Principled BSDF")
    rgb = spec["rgb"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = spec.get("rough", 0.45)
    b.inputs["Metallic"].default_value = spec.get("metal", 0.0)
    b.inputs["Coat Weight"].default_value = spec.get("coat", 0.25)
    emit = spec.get("emit")
    b.inputs["Emission Color"].default_value = (*(emit or (0, 0, 0)), 1)
    b.inputs["Emission Strength"].default_value = spec.get("strength", 0.0) if emit else 0.0
    alpha = spec.get("alpha", 1.0)
    b.inputs["Alpha"].default_value = alpha
    if alpha < 1 and hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    m.diffuse_color = (*rgb, 1)
    return m


# --- Geometry helpers -------------------------------------------------------------

def lathe_into(bm, profile, seg=48, closed=False, mod=None, matfn=None, mat_index=0,
               offset=(0, 0, 0), scale=(1, 1, 1)):
    """Revolves (r, z) profile points around Z. Walk the profile with the outside
    on your right (up the outer wall, inward across tops) so normals face out.
    r == 0 makes a pole. mod(r, z, theta, row) reshapes; matfn(row, theta, center)
    picks a material slot per face."""
    ox, oy, oz = offset
    sx, sy, sz = scale
    rings = []
    for i, (r, z) in enumerate(profile):
        if r < 1e-6 and not closed:
            rings.append([bm.verts.new((ox, oy, oz + z * sz))])
            continue
        ring = []
        for j in range(seg):
            th = tau * j / seg
            rr, zz = mod(r, z, th, i) if mod else (r, z)
            ring.append(bm.verts.new((ox + rr * cos(th) * sx, oy + rr * sin(th) * sy, oz + zz * sz)))
        rings.append(ring)
    n = len(profile)
    pairs = [(i, i + 1) for i in range(n - 1)] + ([(n - 1, 0)] if closed else [])
    for i, k in pairs:
        a, b = rings[i], rings[k]
        for j in range(seg):
            j2 = (j + 1) % seg
            if len(a) == 1:
                vs = (a[0], b[j2], b[j])
            elif len(b) == 1:
                vs = (a[j], a[j2], b[0])
            else:
                vs = (a[j], a[j2], b[j2], b[j])
            f = bm.faces.new(vs)
            if matfn:
                c = sum((v.co for v in vs), Vector()) / len(vs)
                f.material_index = matfn(i, atan2(c.y - oy, c.x - ox) % tau, c)
            else:
                f.material_index = mat_index
    return bm


def bm_lathe(profile, seg=48, **kw):
    return lathe_into(bmesh.new(), profile, seg, **kw)


def sph(r, rings=12):
    return [(r * sin(pi * k / rings), -r * cos(pi * k / rings)) for k in range(rings + 1)]


def bm_sphere(r, seg=32, rings=16):
    return bm_lathe(sph(r, rings), seg)


def torus_profile(R, rr, n=16):
    return [(R + rr * cos(tau * k / n), rr * sin(tau * k / n)) for k in range(n)]


def bm_torus(R, rr, seg=48, n=16):
    return bm_lathe(torus_profile(R, rr, n), seg, closed=True)


def puck(r, h, e):
    """Rounded cylinder profile centered on z=0."""
    return [(0, -h / 2), (r - e, -h / 2), (r, -h / 2 + e), (r, h / 2 - e), (r - e, h / 2), (0, h / 2)]


def bm_spheres(items, seg=16, rings=8):
    """items: (center, radius[, mat_index[, scale]])"""
    bm = bmesh.new()
    for it in items:
        mi = it[2] if len(it) > 2 else 0
        sc = it[3] if len(it) > 3 else (1, 1, 1)
        lathe_into(bm, sph(it[1], rings), seg, mat_index=mi, offset=tuple(it[0]), scale=sc)
    return bm


def fib_sphere(n):
    ga = pi * (3 - 5 ** 0.5)
    out = []
    for k in range(n):
        y = 1 - 2 * (k + 0.5) / n
        rr = (1 - y * y) ** 0.5
        out.append(Vector((rr * cos(ga * k), rr * sin(ga * k), y)))
    return out


def fluff(center, radius, puff, n=26, mats=(0,)):
    c = Vector(center)
    items = [(c, radius * 0.85, mats[0])]
    items += [(c + p * radius, puff, mats[k % len(mats)]) for k, p in enumerate(fib_sphere(n))]
    return items


def bm_grid(fn, nu, nv):
    bm = bmesh.new()
    vs = [[bm.verts.new(fn(u / (nu - 1), v / (nv - 1))) for v in range(nv)] for u in range(nu)]
    for i in range(nu - 1):
        for j in range(nv - 1):
            bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
    return bm


def ccw(outline):
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(outline, outline[1:] + outline[:1]))
    return outline if area > 0 else list(reversed(outline))


def bm_prism(outline, depth):
    """Extrudes a 2D outline (XY) along Z, centered on z=0."""
    outline = ccw(outline)
    bm = bmesh.new()
    h = depth / 2
    bot = [bm.verts.new((x, y, -h)) for x, y in outline]
    top = [bm.verts.new((x, y, h)) for x, y in outline]
    bm.faces.new(list(reversed(bot)))
    bm.faces.new(top)
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    return bm


def star(ro, ri, n=5):
    return [((ro if k % 2 == 0 else ri) * cos(pi / 2 + k * pi / n),
             (ro if k % 2 == 0 else ri) * sin(pi / 2 + k * pi / n)) for k in range(2 * n)]


def superellipse(a, b, p=4.0, n=48):
    out = []
    for k in range(n):
        t = tau * k / n
        c, s = cos(t), sin(t)
        out.append((a * (1 if c >= 0 else -1) * abs(c) ** (2 / p), b * (1 if s >= 0 else -1) * abs(s) ** (2 / p)))
    return out


def ellipse(a, b, n=40):
    return [(a * cos(tau * k / n), b * sin(tau * k / n)) for k in range(n)]


def heart(w, n=56):
    pts = []
    for k in range(n):
        t = tau * k / n
        pts.append((16 * sin(t) ** 3, 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)))
    s = w / 32.0
    cy = (max(p[1] for p in pts) + min(p[1] for p in pts)) / 2
    return [(x * s, (y - cy) * s) for x, y in pts]


def rounded_polygon(corners, rr, steps=6):
    out = []
    n = len(corners)
    for i in range(n):
        a, p, b = Vector(corners[i - 1]), Vector(corners[i]), Vector(corners[(i + 1) % n])
        p1 = p + (a - p).normalized() * rr
        p2 = p + (b - p).normalized() * rr
        for k in range(steps + 1):
            t = k / steps
            q = (1 - t) ** 2 * p1 + 2 * (1 - t) * t * p + t * t * p2
            out.append((q.x, q.y))
    return out


def facing_matrix(normal, up=(0, 0, 1)):
    z = Vector(normal).normalized()
    x = Vector(up).cross(z)
    if x.length < 1e-5:
        x = Vector((1, 0, 0)).cross(z)
    x.normalize()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def facing(normal, up=(0, 0, 1)):
    """Euler that turns local +Z toward `normal`, keeping local +Y near `up`."""
    return facing_matrix(normal, up).to_euler()


# --- Accessory container ------------------------------------------------------------

class Acc:
    def __init__(self, id_, tilt=(0, 0, 0)):
        scn = scene()
        name = "acc_" + id_
        c = bpy.data.collections.get(name)
        if c:
            for o in list(c.objects):
                bpy.data.objects.remove(o, do_unlink=True)
        else:
            c = bpy.data.collections.new(name)
        if c.name not in scn.collection.children:
            scn.collection.children.link(c)
        self.coll = c
        self.root = bpy.data.objects.new(name, None)
        c.objects.link(self.root)
        self.root.rotation_euler = tilt

    def _finish(self, o, parent, loc, rot, scale, subd, bevel, solidify):
        o.parent = parent or self.root
        o.location = loc
        if rot is not None:
            o.rotation_euler = rot
        o.scale = scale
        if solidify:
            s = o.modifiers.new("Solidify", "SOLIDIFY")
            s.thickness = solidify
            s.offset = 0
        if bevel:
            b = o.modifiers.new("Bevel", "BEVEL")
            b.width = bevel
            b.segments = 3
            b.limit_method = "ANGLE"
        if subd:
            s = o.modifiers.new("Subd", "SUBSURF")
            s.levels = subd
            s.render_levels = subd
        return o

    def obj(self, name, bm, mats, subd=0, smooth=True, loc=(0, 0, 0), rot=None, scale=(1, 1, 1),
            bevel=0.0, solidify=0.0, parent=None):
        me = bpy.data.meshes.new(f"{self.root.name}_{name}")
        bm.to_mesh(me)
        bm.free()
        for m in mats:
            me.materials.append(m)
        if smooth:
            me.shade_smooth()
        o = bpy.data.objects.new(me.name, me)
        self.coll.objects.link(o)
        return self._finish(o, parent, loc, rot, scale, subd, bevel, solidify)

    def tube(self, name, pts, radii, mat, cyclic=False, subd=0, loc=(0, 0, 0), rot=None,
             scale=(1, 1, 1), parent=None, res=12):
        cu = bpy.data.curves.new(f"{self.root.name}_{name}_curve", "CURVE")
        cu.dimensions = "3D"
        cu.bevel_mode = "ROUND"
        cu.bevel_depth = 1.0
        cu.bevel_resolution = 4
        cu.use_fill_caps = True
        cu.resolution_u = res
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts) - 1)
        sp.use_cyclic_u = cyclic
        if isinstance(radii, (int, float)):
            radii = [radii] * len(pts)
        for bp, p, r in zip(sp.bezier_points, pts, radii):
            bp.co = p
            bp.handle_left_type = bp.handle_right_type = "AUTO"
            bp.radius = r
        tmp = bpy.data.objects.new(cu.name, cu)
        self.coll.objects.link(tmp)
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
        bpy.data.objects.remove(tmp, do_unlink=True)
        bpy.data.curves.remove(cu)
        me.name = f"{self.root.name}_{name}"
        me.materials.clear()
        me.materials.append(mat)
        me.shade_smooth()
        o = bpy.data.objects.new(me.name, me)
        self.coll.objects.link(o)
        return self._finish(o, parent, loc, rot, scale, subd, 0, 0)

    def outline_tube(self, name, outline, loc, normal, radius, mat, up=(0, 0, 1), scale=1.0):
        R = facing_matrix(normal, up)
        pts = [Vector(loc) + R @ Vector((x * scale, y * scale, 0)) for x, y in outline[::2]]
        return self.tube(name, pts, radius, mat, cyclic=True)

    def empty(self, name, loc=(0, 0, 0), parent=None):
        e = bpy.data.objects.new(f"{self.root.name}_{name}", None)
        self.coll.objects.link(e)
        e.parent = parent or self.root
        e.location = loc
        return e

    def arc_band(self, mat, radius=1.05, y=0.1, r=0.05, a0=0.12, a1=pi - 0.12, n=11):
        """A headband arching over the top of the head, ear to ear."""
        pts = [(radius * cos(a0 + (a1 - a0) * k / (n - 1)), y, radius * sin(a0 + (a1 - a0) * k / (n - 1)))
               for k in range(n)]
        return self.tube("band", pts, r, mat)


# --- Classic hats -------------------------------------------------------------------

def build_crown():
    A = Acc("crown", BACK_TILT)

    def peak(th):
        x = ((th - FRONT) / tau * 5 + 0.5) % 1.0
        return (1 - abs(x * 2 - 1)) ** 1.5

    band = [(0.665, 0.84), (0.715, 0.85), (0.725, 0.93), (0.725, 1.06), (0.72, 1.12), (0.7, 1.15),
            (0.665, 1.15), (0.655, 1.12), (0.655, 0.93), (0.65, 0.86)]

    def mod(r, z, th, i):
        if z > 1.0:
            z += 0.46 * peak(th) * min(1.0, (z - 1.0) / 0.15)
        return r, z

    A.obj("band", bm_lathe(band, 90, closed=True, mod=mod), [M("gold")], subd=1)
    cushion = [(0.66, 0.92), (0.64, 1.1), (0.55, 1.26), (0.38, 1.37), (0.18, 1.42), (0, 1.43)]
    A.obj("velvet", bm_lathe(cushion, 48, mod=lambda r, z, th, i: (r * (1 + 0.05 * cos(5 * (th - FRONT)) * min(1, i / 2)), z)),
          [M("velvet")], subd=1)
    A.obj("orb", bm_sphere(0.09), [M("gold")], loc=(0, 0, 1.48), subd=1)
    tips = [((0.71 * cos(FRONT + k * tau / 5), 0.71 * sin(FRONT + k * tau / 5), 1.67), 0.075) for k in range(5)]
    A.obj("tips", bm_spheres(tips), [M("gold")], subd=1)
    pearls = [((0.738 * cos(tau * k / 40), 0.738 * sin(tau * k / 40), 0.865), 0.032) for k in range(40)]
    A.obj("pearls", bm_spheres(pearls, 12, 6), [M("pearl")])
    gem = [(0, -0.05), (0.1, -0.012), (0.1, 0.012), (0.062, 0.05), (0, 0.056)]
    kinds = ["ruby", "sapphire", "emerald", "sapphire", "emerald"]
    for k in range(5):
        th = FRONT + (k + 0.5) * tau / 5
        A.obj(f"gem{k}", bm_lathe(gem, 8), [M(kinds[k])], smooth=False,
              loc=(0.735 * cos(th), 0.735 * sin(th), 0.99), rot=facing((cos(th), sin(th), 0)), scale=(0.75, 0.75, 0.75))
    A.obj("gemFront", bm_lathe(gem, 8), [M("ruby")], smooth=False,
          loc=(0, -0.745, 1.0), rot=facing((0, -1, 0)), scale=(1.1, 1.1, 1.1))


def build_cap():
    A = Acc("cap", (-0.1, 0, 0))
    dome = [(0.76, 0.68), (0.78, 0.8), (0.75, 0.97), (0.64, 1.14), (0.46, 1.27), (0.24, 1.34), (0, 1.36)]

    def panel(i, th, c):
        d = (th - FRONT + pi) % tau - pi
        return 1 if abs(d) < pi / 3 else 0

    A.obj("crown", bm_lathe(dome, 60, matfn=panel), [M("yellow"), M("cream")], subd=1)
    for k in range(6):
        th = FRONT + k * pi / 3
        pts = [(r * 1.012 * cos(th), r * 1.012 * sin(th), z + 0.004) for r, z in dome[:-1]] + [(0, 0, 1.37)]
        A.tube(f"seam{k}", pts, 0.013, M("orange"))
    A.obj("button", bm_sphere(0.085), [M("orange")], loc=(0, 0, 1.37), scale=(1, 1, 0.6), subd=1)

    def brim(uu, vv):
        u = uu * 2 - 1
        phi = FRONT + u * 1.0
        length = 0.62 * (1 - u * u) ** 0.55 + 0.03
        rad = 0.74 + vv * length
        return (rad * cos(phi), rad * sin(phi), 0.69 - 0.05 * vv - 0.12 * u * u * vv)

    A.obj("brim", bm_grid(brim, 23, 9), [M("orange")], solidify=0.06, subd=1)
    eyelets = [((0.62 * cos(FRONT + a), 0.62 * sin(FRONT + a), 1.14), 0.03) for a in (0.9, -0.9, pi - 0.9, pi + 0.9)]
    A.obj("eyelets", bm_spheres(eyelets, 12, 6), [M("orange")], scale=(1, 1, 1))


def build_party():
    A = Acc("party", (-0.12, 0.2, 0))
    prof = [(0.54 * (1 - k / 16), 0.8 + 1.15 * k / 16) for k in range(16)] + [(0, 1.95)]

    def stripe(i, th, c):
        return int(((c.z - 0.8) * 2.4 + th / tau) % 1.0 < 0.5)

    A.obj("cone", bm_lathe(prof, 56, matfn=stripe), [M("pink"), M("yellow")], subd=1)
    A.obj("trim", bm_torus(0.55, 0.06, 56, 12), [M("gold")], loc=(0, 0, 0.8), subd=1)
    A.obj("pompom", bm_spheres(fluff((0, 0, 2.02), 0.11, 0.085, 28)), [M("cloth")])
    dots = []
    for k in range(9):
        th = k * tau / 9 + (k % 3) * 0.4
        z = 0.95 + (k % 3) * 0.28
        r = 0.54 * (1 - (z - 0.8) / 1.15) + 0.02
        dots.append(((r * cos(th), r * sin(th), z), 0.05))
    A.obj("confetti", bm_spheres(dots, 12, 6), [M("blue")], scale=(1, 1, 1))


def build_chef():
    A = Acc("chef", BACK_TILT)
    band = [(0.6, 0.8), (0.635, 0.82), (0.645, 0.9), (0.645, 1.1), (0.62, 1.14)]
    A.obj("band", bm_lathe(band, 72, mod=lambda r, z, th, i: (r * (1 + 0.022 * cos(24 * th)), z)), [M("cloth")], subd=1)
    puff = [(0.56, 1.1), (0.72, 1.16), (0.86, 1.3), (0.92, 1.48), (0.88, 1.66), (0.72, 1.8), (0.46, 1.9), (0.2, 1.94), (0, 1.94)]
    n = len(puff)

    def pm(r, z, th, i):
        t = i / (n - 1)
        k = sin(pi * min(1, t * 1.3))
        return r * (1 + 0.075 * cos(7 * th) * k), z + 0.05 * cos(7 * th) * t

    A.obj("puff", bm_lathe(puff, 70, mod=pm), [M("cloth")], subd=1)


def build_viking():
    A = Acc("viking", BACK_TILT)
    dome = [(0.8, 0.6), (0.82, 0.72), (0.79, 0.92), (0.68, 1.12), (0.48, 1.28), (0.25, 1.36), (0, 1.38)]
    A.obj("dome", bm_lathe(dome, 56), [M("steel")], subd=1)
    rim = [(0.8, 0.56), (0.88, 0.56), (0.9, 0.61), (0.9, 0.71), (0.87, 0.75), (0.8, 0.75)]
    A.obj("rim", bm_lathe(rim, 56, closed=True), [M("bronze")], subd=1)

    def meridian(th):
        return [(r * 1.035 * cos(th), r * 1.035 * sin(th), z) for r, z in dome[:-1]]

    top = [(0, 0, 1.415)]
    A.tube("strapFB", meridian(FRONT)[1:] + top + list(reversed(meridian(pi / 2)))[:-1], 0.05, M("bronze"))
    A.tube("strapLR", meridian(0)[1:] + top + list(reversed(meridian(pi)))[:-1], 0.05, M("bronze"))
    rivets = [((0.905 * cos(tau * k / 18), 0.905 * sin(tau * k / 18), 0.66), 0.035) for k in range(18)]
    for th in (FRONT, pi / 2, 0, pi):
        rivets += [((r * 1.08 * cos(th), r * 1.08 * sin(th), z + 0.01), 0.03) for r, z in dome[2:5]]
    A.obj("rivets", bm_spheres(rivets, 12, 6), [M("steel")])
    for sx in (-1, 1):
        pts = [(sx * 0.74, 0.0, 0.92), (sx * 1.02, -0.02, 1.0), (sx * 1.24, -0.06, 1.25), (sx * 1.3, -0.1, 1.55), (sx * 1.18, -0.12, 1.84)]
        A.tube(f"horn{sx}", pts, [0.21, 0.19, 0.14, 0.08, 0.012], M("bone"))
        A.obj(f"collar{sx}", bm_torus(0.19, 0.045, 32, 10), [M("bronze")], loc=(sx * 0.86, -0.008, 0.95),
              rot=facing((sx * 1.0, 0, 0.32)), subd=1)


def build_tophat():
    A = Acc("tophat", BACK_TILT)
    prof = [(0.62, 0.86), (0.9, 0.84), (1.08, 0.86), (1.12, 0.9), (1.08, 0.93), (0.9, 0.9), (0.64, 0.92),
            (0.6, 1.0), (0.6, 1.4), (0.63, 1.72), (0.62, 1.78), (0.5, 1.8), (0, 1.8)]

    def curl(r, z, th, i):
        if r > 0.7:
            z += 0.22 * cos(th) ** 2 * ((r - 0.7) / 0.42) ** 2
        return r, z

    A.obj("hat", bm_lathe(prof, 64, mod=curl), [M("black")], subd=1)
    A.obj("ribbon", bm_lathe([(0.605, 0.93), (0.625, 0.95), (0.625, 1.11), (0.605, 1.13)], 64), [M("satin")], subd=1)
    A.outline_tube("buckle", superellipse(0.11, 0.085, 5, 32), (0, -0.635, 1.03), (0, -1, 0), 0.016, M("gold"))


def build_propeller():
    A = Acc("propeller", (-0.12, 0, 0))
    dome = [(0.76, 0.7), (0.77, 0.8), (0.73, 0.98), (0.62, 1.14), (0.44, 1.26), (0.22, 1.32), (0, 1.34)]

    def quad(i, th, c):
        return int(((th - FRONT + pi / 4) % tau) / (pi / 2))

    A.obj("dome", bm_lathe(dome, 64, matfn=quad), [M("red"), M("yellow"), M("blue"), M("green")], subd=2)
    A.obj("band", bm_lathe([(0.76, 0.66), (0.8, 0.66), (0.81, 0.71), (0.78, 0.76)], 64, closed=True), [M("white")], subd=1)
    A.obj("stem", bm_lathe(puck(0.045, 0.22, 0.01), 16), [M("gold")], loc=(0, 0, 1.42))
    spin = A.empty("spin", (0, 0, 1.53))
    A.obj("hub", bm_sphere(0.07), [M("gold")], parent=spin, subd=1)
    blade = ellipse(0.24, 0.075, 32)
    for k, col in enumerate(("red", "blue")):
        # Same pitch on both blades, the second turned half a revolution.
        A.obj(f"blade{k}", bm_prism([(x + 0.25, y) for x, y in blade], 0.035), [M(col)], parent=spin,
              rot=(0.35, 0, k * pi), smooth=False, bevel=0.012)


# --- Classic face -------------------------------------------------------------------

def build_shades():
    A = Acc("shades")
    lens = superellipse(0.31, 0.23, 3.6, 48)
    for sx in (-1, 1):
        n = (sx * 0.2, -1, 0)
        loc = (sx * 0.37, -1.05, 0.42)
        A.obj(f"lens{sx}", bm_prism(lens, 0.04), [M("glassDark")], smooth=False, loc=loc, rot=facing(n), bevel=0.012)
        A.outline_tube(f"frame{sx}", lens, loc, n, 0.03, M("black"), scale=1.05)
        A.tube(f"arm{sx}", [(sx * 0.68, -0.98, 0.5), (sx * 0.9, -0.62, 0.52), (sx * 1.01, -0.15, 0.48)], 0.028, M("black"))
    A.tube("bridge", [(-0.08, -1.08, 0.52), (0, -1.1, 0.56), (0.08, -1.08, 0.52)], 0.028, M("black"))
    shine = [((sx * 0.37 - 0.1, -1.08, 0.52), 0.03, 0, (1.6, 0.5, 1)) for sx in (-1, 1)]
    A.obj("shine", bm_spheres(shine), [M("white")])


def build_mustache():
    A = Acc("mustache")
    for sx in (-1, 1):
        pts = [(0, -1.03, 0.0), (sx * 0.22, -1.0, -0.03), (sx * 0.45, -0.93, 0.02), (sx * 0.6, -0.83, 0.16),
               (sx * 0.57, -0.81, 0.3), (sx * 0.47, -0.86, 0.27)]
        A.tube(f"side{sx}", pts, [0.11, 0.12, 0.09, 0.06, 0.035, 0.02], M("brown"))


def build_glasses():
    A = Acc("glasses")
    for sx in (-1, 1):
        loc = (sx * 0.38, -1.04, 0.38)
        A.obj(f"rim{sx}", bm_torus(0.27, 0.035, 48, 10), [M("tortoise")], loc=loc, rot=facing((sx * 0.15, -1, 0)), subd=1)
        A.obj(f"lens{sx}", bm_lathe(puck(0.26, 0.015, 0.004), 40), [M("glassClear")], loc=loc, rot=facing((sx * 0.15, -1, 0)))
        A.tube(f"arm{sx}", [(sx * 0.65, -0.98, 0.42), (sx * 0.9, -0.62, 0.46), (sx * 1.01, -0.15, 0.44)], 0.025, M("tortoise"))
    A.tube("bridge", [(-0.12, -1.06, 0.42), (0, -1.1, 0.5), (0.12, -1.06, 0.42)], 0.025, M("tortoise"))


def build_cowboy():
    A = Acc("cowboy", BACK_TILT)
    prof = [(0.62, 0.8), (1.0, 0.78), (1.26, 0.8), (1.3, 0.84), (1.25, 0.87), (1.0, 0.85), (0.66, 0.86),
            (0.62, 0.95), (0.6, 1.25), (0.56, 1.42), (0.4, 1.46), (0.2, 1.4), (0, 1.36)]

    def shape(r, z, th, i):
        if r > 0.72 and z < 0.9:
            k = (r - 0.72) / 0.58
            z += 0.42 * cos(th) ** 2 * k ** 2 - 0.05 * sin(th) ** 2 * k
        if z > 1.1:
            front = max(0.0, -sin(th))
            r *= 1 - 0.18 * front ** 3 * (z - 1.1) / 0.36
        return r, z

    A.obj("hat", bm_lathe(prof, 72, mod=shape), [M("felt")], subd=1)
    A.obj("band", bm_lathe([(0.625, 0.88), (0.64, 0.9), (0.635, 1.02), (0.62, 1.04)], 72), [M("leather")], subd=1)
    A.obj("concho", bm_lathe(puck(0.075, 0.03, 0.01), 24), [M("silver")], loc=(0.65, 0, 0.96), rot=facing((1, 0, 0)))
    A.obj("star", bm_prism(star(0.045, 0.02), 0.02), [M("gold")], smooth=False, loc=(0.67, 0, 0.96), rot=facing((1, 0, 0)))


def build_wizard():
    A = Acc("wizard", BACK_TILT)
    A.obj("brim", bm_lathe([(0.62, 0.82), (1.0, 0.8), (1.1, 0.82), (1.12, 0.85), (1.07, 0.88), (0.9, 0.87), (0.64, 0.88)], 64,
                           mod=lambda r, z, th, i: (r * (1 + 0.035 * sin(6 * th)) if r > 0.8 else r, z)), [M("wizard")], subd=1)
    pts = [(0, 0.02, 0.75), (0, 0.05, 1.3), (0, 0.18, 1.85), (0, 0.45, 2.2), (0, 0.78, 2.28)]
    A.tube("cone", pts, [0.66, 0.5, 0.3, 0.12, 0.02], M("wizard"))
    A.obj("band", bm_lathe([(0.64, 0.86), (0.655, 0.88), (0.635, 0.98), (0.62, 1.0)], 64), [M("starGold")], subd=1)
    for k, (dth, z, s) in enumerate([(0, 1.18, 1.0), (-0.55, 1.42, 0.8), (0.6, 1.55, 0.7), (-0.2, 1.72, 0.6), (0.3, 1.35, 0.55)]):
        th = FRONT + dth
        r = 0.66 + (0.5 - 0.66) * (z - 0.75) / 0.55 if z < 1.3 else 0.5 + (0.3 - 0.5) * (z - 1.3) / 0.55
        yc = 0.02 + 0.03 * (z - 0.75) / 0.55 if z < 1.3 else 0.05 + 0.13 * (z - 1.3) / 0.55
        p = (r * 1.01 * cos(th), yc + r * 1.01 * sin(th), z)
        A.obj(f"star{k}", bm_prism(star(0.1 * s, 0.045 * s), 0.03), [M("starGold")], smooth=False,
              loc=p, rot=facing((cos(th), sin(th), 0.3)), bevel=0.008)


def build_beanie():
    A = Acc("beanie", (-0.1, 0, 0))
    dome = [(0.78, 0.62), (0.8, 0.75), (0.78, 0.95), (0.68, 1.14), (0.5, 1.28), (0.26, 1.36), (0, 1.38)]

    def stripes(i, th, c):
        return int(((c.z - 0.9) / 0.13)) % 2 if c.z > 0.9 else 0

    A.obj("dome", bm_lathe(dome, 80, mod=lambda r, z, th, i: (r * (1 + 0.02 * cos(40 * th)), z), matfn=stripes),
          [M("knitRed"), M("knitCream")], subd=1)
    cuff = [(0.79, 0.56), (0.86, 0.56), (0.885, 0.62), (0.885, 0.8), (0.85, 0.84), (0.79, 0.84)]
    A.obj("cuff", bm_lathe(cuff, 80, closed=True, mod=lambda r, z, th, i: (r * (1 + 0.028 * cos(40 * th)), z)),
          [M("knitCream")], subd=1)
    A.obj("pompom", bm_spheres(fluff((0, 0, 1.52), 0.18, 0.1, 30, mats=(0, 1))), [M("knitRed"), M("knitCream")])


def build_bunny():
    A = Acc("bunny")
    A.arc_band(M("furPink"), r=0.045)
    for sx in (-1, 1):
        base = Vector((sx * 0.33, 0.12, 0.98))
        if sx < 0:
            rel = [(0, 0, 0), (-0.04, 0.02, 0.4), (-0.06, 0.04, 0.82), (-0.03, 0.05, 1.12)]
        else:
            rel = [(0, 0, 0), (0.08, 0.02, 0.38), (0.32, 0.04, 0.62), (0.62, 0.06, 0.58)]
        A.tube(f"ear{sx}", rel, [0.1, 0.2, 0.19, 0.04], M("fur"), loc=base, scale=(1, 0.4, 1))
        inner = [(x, y, z) for x, y, z in rel][1:]
        A.tube(f"inner{sx}", inner, [0.12, 0.11, 0.02], M("furPink"), loc=base + Vector((0, -0.055, 0)), scale=(1, 0.22, 1))


def build_halo():
    A = Acc("halo", BACK_TILT)
    A.obj("ring", bm_torus(0.66, 0.1, 64, 16), [M("halo")], loc=(0, 0.08, 1.38), rot=(-0.12, 0, 0), subd=1)
    for k, a in enumerate((0.5, 2.4, 4.3)):
        p = (0.66 * cos(a), 0.08 + 0.66 * sin(a), 1.5)
        A.obj(f"sparkle{k}", bm_prism(star(0.07, 0.025, 4), 0.02), [M("halo")], smooth=False, loc=p,
              rot=facing((0.3, -1, 0.2)))


def build_unicorn():
    A = Acc("unicorn")
    n = 26
    prof = [(0.26 * (1 - k / n) ** 0.85, 1.05 * k / n) for k in range(n)] + [(0, 1.06)]
    A.obj("horn", bm_lathe(prof, 56, mod=lambda r, z, th, i: (r * (1 - 0.14 * (0.5 + 0.5 * sin(th - z * 22))), z)),
          [M("unicorn")], loc=(0, -0.3, 0.9), rot=facing((0, -0.42, 1), up=(0, 1, 0)), subd=1)
    mane = fluff((0, -0.05, 1.08), 0.16, 0.09, 18, mats=(0, 1, 2)) + fluff((0, 0.28, 1.05), 0.16, 0.09, 18, mats=(1, 2, 0)) \
        + fluff((0, 0.58, 0.88), 0.15, 0.08, 16, mats=(2, 0, 1))
    A.obj("mane", bm_spheres(mane, 12, 6), [M("maneP"), M("maneL"), M("maneM")])
    for sx in (-1, 1):
        A.obj(f"ear{sx}", bm_lathe([(0.16, 0), (0.14, 0.15), (0.08, 0.3), (0, 0.38)], 24), [M("fur")],
              loc=(sx * 0.55, 0.12, 0.8), rot=facing((sx * 0.7, 0.1, 1)), scale=(1, 0.55, 1), subd=1)


def build_headphones():
    A = Acc("headphones")
    A.arc_band(M("white"), radius=1.12, y=0.04, r=0.065, a0=0.15, a1=pi - 0.15)
    A.tube("pad", [(1.1 * cos(a), 0.04, 1.1 * sin(a)) for a in (1.05, 1.3, 1.57, 1.84, 2.09)], 0.09, M("phone"))
    for sx in (-1, 1):
        A.obj(f"cup{sx}", bm_lathe(puck(0.37, 0.28, 0.08), 48), [M("phone")], loc=(sx * 1.12, 0.04, 0.2),
              rot=facing((sx, 0, 0)), subd=1)
        A.obj(f"cushion{sx}", bm_torus(0.26, 0.075, 40, 12), [M("cushion")], loc=(sx * 0.98, 0.04, 0.2),
              rot=facing((sx, 0, 0)), subd=1)
        A.obj(f"logo{sx}", bm_lathe(puck(0.15, 0.03, 0.01), 32), [M("white")], loc=(sx * 1.27, 0.04, 0.2),
              rot=facing((sx, 0, 0)))


def build_pirate():
    A = Acc("pirate", BACK_TILT)
    prof = [(0.62, 0.84), (1.0, 0.82), (1.18, 0.84), (1.2, 0.88), (1.15, 0.9), (0.9, 0.89), (0.64, 0.9),
            (0.6, 1.0), (0.58, 1.25), (0.45, 1.36), (0.2, 1.4), (0, 1.4)]

    def tricorn(r, z, th, i):
        c = max(0.0, cos(3 * (th - FRONT)))
        if r > 0.66 and z < 0.95:
            k = (r - 0.66) / 0.54
            r = 0.66 + (r - 0.66) * (1 + 0.32 * c)
            z += 0.55 * k ** 1.4 * (1 - 0.85 * c)
        return r, z

    A.obj("hat", bm_lathe(prof, 90, mod=tricorn, matfn=lambda i, th, c: 1 if i in (2, 3, 4) else 0),
          [M("pirate"), M("gold")], subd=1)
    A.obj("skull", bm_spheres([((0, -0.62, 1.15), 0.1), ((0, -0.61, 1.07), 0.06, 0, (1.2, 1, 0.8))]), [M("bone")], subd=1)
    A.obj("sockets", bm_spheres([((sx * 0.038, -0.705, 1.16), 0.026) for sx in (-1, 1)], 12, 6), [M("pirate")])
    for k, a in enumerate((0.6, -0.6)):
        A.tube(f"bone{k}", [(-0.13 * cos(a), -0.64, 1.0 - 0.13 * sin(a)), (0.13 * cos(a), -0.64, 1.0 + 0.13 * sin(a))],
               0.018, M("bone"))


# --- More face items ------------------------------------------------------------------

def build_clown():
    A = Acc("clown")
    A.obj("nose", bm_sphere(0.2), [M("clown")], loc=(0, -1.08, 0.12), subd=1)
    A.obj("shine", bm_sphere(0.04), [M("white")], loc=(-0.07, -1.24, 0.2), scale=(1.4, 0.6, 1))


def build_monocle():
    A = Acc("monocle")
    loc = (0.39, -1.05, 0.37)
    A.obj("ring", bm_torus(0.28, 0.04, 48, 10), [M("gold")], loc=loc, rot=facing((0.1, -1, 0)), subd=1)
    A.obj("lens", bm_lathe(puck(0.27, 0.015, 0.004), 40), [M("glassClear")], loc=loc, rot=facing((0.1, -1, 0)))
    A.tube("chain", [(0.42, -1.04, 0.09), (0.52, -0.98, -0.2), (0.72, -0.76, -0.45), (0.86, -0.46, -0.55)], 0.016, M("gold"))


def build_heart():
    A = Acc("heart")
    shape = heart(0.62)
    for sx in (-1, 1):
        n = (sx * 0.18, -1, 0)
        loc = (sx * 0.38, -1.05, 0.38)
        A.obj(f"lens{sx}", bm_prism(shape, 0.04), [M("heartGlass")], smooth=False, loc=loc, rot=facing(n), bevel=0.01)
        A.outline_tube(f"frame{sx}", shape, loc, n, 0.03, M("heartFrame"), scale=1.04)
        A.tube(f"arm{sx}", [(sx * 0.68, -0.98, 0.5), (sx * 0.9, -0.62, 0.52), (sx * 1.01, -0.15, 0.48)], 0.026, M("heartFrame"))
    A.tube("bridge", [(-0.09, -1.08, 0.5), (0, -1.1, 0.54), (0.09, -1.08, 0.5)], 0.026, M("heartFrame"))


def build_eyepatch():
    A = Acc("eyepatch")
    A.obj("patch", bm_prism(superellipse(0.34, 0.32, 2.6, 48), 0.07), [M("pirate")], smooth=False,
          loc=(-0.39, -1.07, 0.38), rot=facing((-0.25, -1, 0)), bevel=0.03)
    A.obj("stitch", bm_prism(star(0.05, 0.02, 5), 0.02), [M("bone")], smooth=False,
          loc=(-0.41, -1.115, 0.4), rot=facing((-0.25, -1, 0)))
    A.tube("strapA", [(-0.66, -0.88, 0.44), (-0.92, -0.45, 0.47), (-1.02, 0.1, 0.52), (-0.72, 0.68, 0.58), (0, 1.03, 0.62)],
           0.035, M("pirate"))
    A.tube("strapB", [(-0.24, -1.0, 0.58), (0.02, -0.88, 0.92), (0.42, -0.55, 1.06), (0.78, 0.08, 0.96),
                      (0.62, 0.62, 0.76), (0, 1.02, 0.62)], 0.035, M("pirate"))


# --- Halloween ------------------------------------------------------------------------

def build_witch():
    A = Acc("witch", BACK_TILT)
    brim = [(0.62, 0.84), (0.95, 0.82), (1.2, 0.82), (1.24, 0.86), (1.2, 0.89), (0.95, 0.87), (0.64, 0.88)]

    def wave(r, z, th, i):
        if r > 0.7:
            k = (r - 0.7) / 0.54
            r *= 1 + 0.05 * sin(5 * th + 1) * k
            z += 0.06 * sin(5 * th) * k
        return r, z

    A.obj("brim", bm_lathe(brim, 80, mod=wave), [M("witch")], subd=1)
    pts = [(0, 0.0, 0.78), (0, 0.04, 1.3), (0, 0.12, 1.75), (0, 0.32, 2.1), (0, 0.62, 2.2), (0, 0.82, 2.06)]
    A.tube("cone", pts, [0.62, 0.46, 0.3, 0.16, 0.07, 0.02], M("witch"))
    A.obj("band", bm_lathe([(0.6, 0.86), (0.62, 0.88), (0.585, 1.04), (0.565, 1.06)], 64), [M("witchBand")], subd=1)
    A.outline_tube("buckle", superellipse(0.12, 0.1, 5, 32), (0, -0.635, 0.97), (0, -1, 0.1), 0.02, M("gold"))


def build_pumpkin():
    A = Acc("pumpkin", (-0.12, 0, 0))
    PC, PH, PR = 1.38, 0.56, 0.8

    def lobe(th):
        return 0.88 + 0.12 * abs(cos(5 * (th - FRONT))) ** 0.6

    prof = []
    for k in range(19):
        phi = pi * k / 18
        z = PC - PH * cos(phi) - 0.12 * max(0.0, (phi / pi - 0.8) / 0.2) ** 2
        prof.append((PR * sin(phi), z))
    A.obj("body", bm_lathe(prof, 80, mod=lambda r, z, th, i: (r * lobe(th), z)), [M("pumpkin")], subd=1)

    def surface(th, z):
        c = (PC - z) / PH
        s = max(0.0, 1 - c * c) ** 0.5
        r = PR * s * lobe(th)
        p = Vector((r * cos(th), r * sin(th), z))
        n = Vector((p.x / PR ** 2, p.y / PR ** 2, (z - PC) / PH ** 2)).normalized()
        return p, n

    eye = rounded_polygon([(-0.1, -0.07), (0.1, -0.07), (0, 0.11)], 0.018)
    for k, dth in enumerate((-0.42, 0.42)):
        p, n = surface(FRONT + dth, 1.52)
        A.obj(f"eye{k}", bm_prism(eye, 0.07), [M("glow")], smooth=False, loc=p + n * 0.01, rot=facing(n))
    p, n = surface(FRONT, 1.36)
    A.obj("nose", bm_prism(rounded_polygon([(-0.05, -0.04), (0.05, -0.04), (0, 0.05)], 0.01), 0.07), [M("glow")],
          smooth=False, loc=p + n * 0.01, rot=facing(n))
    top, bot = [], []
    for k in range(13):
        u = -1 + 2 * k / 12
        top.append((u * 0.25, 0.03 + 0.08 * u * u))
        bot.append((u * 0.25, -0.07 + 0.11 * u * u))
    top[4] = (top[4][0], top[4][1] - 0.055)
    top[8] = (top[8][0], top[8][1] - 0.055)
    bot[6] = (bot[6][0], bot[6][1] + 0.055)
    p, n = surface(FRONT, 1.18)
    A.obj("mouth", bm_prism(top + list(reversed(bot)), 0.09), [M("glow")], smooth=False, loc=p + n * 0.02, rot=facing(n))
    A.tube("stem", [(0, 0, 1.78), (0, 0.02, 1.95), (0.05, 0.06, 2.06), (0.13, 0.1, 2.1)], [0.1, 0.085, 0.075, 0.07], M("stem"))
    leaf = [(0.2 * cos(t), 0.09 * sin(t) * (1 - 0.3 * cos(t))) for t in [tau * k / 32 for k in range(32)]]
    A.obj("leaf", bm_prism(leaf, 0.02), [M("leaf")], smooth=False, loc=(0.22, -0.1, 1.86),
          rot=facing((0.35, -0.2, 1), up=(1, 0, 0)), bevel=0.006)
    vine = [(-0.04 + 0.1 * cos(a), 0.12 + 0.1 * sin(a), 1.85 + 0.03 * a) for a in [k * 0.6 for k in range(12)]]
    A.tube("vine", vine, 0.016, M("leaf"))


def build_devil():
    A = Acc("devil")
    A.arc_band(M("devil"), r=0.04, y=0.0)
    for sx in (-1, 1):
        pts = [(sx * 0.4, -0.15, 0.9), (sx * 0.52, -0.18, 1.14), (sx * 0.55, -0.15, 1.34), (sx * 0.45, -0.1, 1.5)]
        A.tube(f"horn{sx}", pts, [0.14, 0.11, 0.065, 0.01], M("devil"))


def build_cat():
    A = Acc("cat")
    A.arc_band(M("catBlack"), r=0.045, y=0.05)
    outer = rounded_polygon([(-0.24, 0), (0.24, 0), (0.02, 0.48)], 0.06)
    inner = rounded_polygon([(-0.15, 0.02), (0.15, 0.02), (0.02, 0.34)], 0.04)
    for sx in (-1, 1):
        base = (sx * 0.5, 0.04, 0.9)
        n = (0, -1, 0.15)
        up = (sx * 0.35, 0, 1)
        A.obj(f"ear{sx}", bm_prism(outer, 0.12), [M("catBlack")], smooth=False, loc=base, rot=facing(n, up), bevel=0.04)
        A.obj(f"inner{sx}", bm_prism(inner, 0.04), [M("furPink")], smooth=False,
              loc=(base[0], base[1] - 0.065, base[2] + 0.02), rot=facing(n, up), bevel=0.012)


def build_mummy():
    A = Acc("mummy")

    def wrap(name, tilt, d, width=0.2, thick=0.05, wobble=0.0, roll=0.0):
        n = Vector((sin(roll), sin(tilt), cos(tilt))).normalized()
        # Above the equator wrap the head sphere; below it, hug the thumb's neck
        # (a cylinder), so center the ring on the axis.
        if d >= 0:
            R, loc = (1.03 ** 2 - d ** 2) ** 0.5, n * d
        else:
            R, loc = 0.99, Vector((0, 0, d))
        prof = [(R, -width / 2), (R + thick, -width / 2), (R + thick, width / 2), (R, width / 2)]
        A.obj(name, bm_lathe(prof, 72, closed=True,
                             mod=lambda r, z, th, i: (r + 0.012 * sin(7 * th + wobble), z + 0.025 * sin(3 * th + wobble))),
              [M("bandage")], loc=loc, rot=facing(n), subd=1)

    wrap("fore", 0.3, 0.61, wobble=0.3)
    wrap("cap", 0.2, 0.9)
    wrap("top", 0.45, 0.7, wobble=0.6, roll=0.25)
    wrap("diag", 0.62, 0.48, wobble=1.0, roll=-0.3)
    wrap("back", 1.0, 0.3, wobble=1.7)
    wrap("low", -0.12, -0.42, wobble=2.0)
    wrap("low2", 0.14, -0.68, wobble=3.0)
    for k, (axis, d) in enumerate((((0.25, 1, 0.1), 0.2), ((-0.3, 1, 0.05), 0.45))):
        side = Vector(axis).normalized()
        R = (1.03 ** 2 - d ** 2) ** 0.5
        A.obj(f"side{k}", bm_lathe([(R, -0.09), (R + 0.05, -0.09), (R + 0.05, 0.09), (R, 0.09)], 72, closed=True,
                                   mod=lambda r, z, th, i: (r + 0.01 * sin(6 * th), z + 0.02 * sin(4 * th))),
              [M("bandage")], loc=side * d, rot=facing(side), subd=1)
    A.tube("tail", [(0.9, 0.35, -0.3), (1.02, 0.3, -0.55), (0.98, 0.32, -0.8)], 0.06, M("bandage"), scale=(1, 0.45, 1))


def build_frankenstein():
    A = Acc("frankenstein")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 1.42, v.co.y * 1.36, v.co.z * 0.6))
    o = A.obj("hair", bm, [M("frankHair")], loc=(0, 0.08, 1.06))
    b = o.modifiers.new("Bevel", "BEVEL")
    b.width = 0.1
    b.segments = 3
    s = o.modifiers.new("Subd", "SUBSURF")
    s.levels = s.render_levels = 1
    fringe = [(-0.66, 0.16), (0.66, 0.16)]
    for k in range(11):
        x = 0.66 - k * 1.32 / 10
        fringe.append((x, -0.1 if k % 2 == 0 else 0.02))
    A.obj("fringe", bm_prism(fringe, 0.12), [M("frankHair")], smooth=False, loc=(0, -0.64, 0.86), rot=facing((0, -1, 0.15)),
          bevel=0.025)
    for sx in (-1, 1):
        A.obj(f"bolt{sx}", bm_lathe(puck(0.1, 0.4, 0.03), 24), [M("steel")], loc=(sx * 0.98, 0.05, -0.38),
              rot=facing((sx, 0, 0)), subd=1)
        hexa = [(0.16 * cos(tau * k / 6), 0.16 * sin(tau * k / 6)) for k in range(6)]
        A.obj(f"nut{sx}", bm_prism(hexa, 0.09), [M("steel")], smooth=False, loc=(sx * 1.16, 0.05, -0.38),
              rot=facing((sx, 0, 0)), bevel=0.02)
    A.tube("scar", [(0.8, -0.52, -0.02), (0.88, -0.36, 0.06), (0.93, -0.18, 0.14)], 0.018, M("scar"))
    for k, t in enumerate((0.25, 0.5, 0.75)):
        c = Vector((0.8, -0.52, -0.02)).lerp(Vector((0.93, -0.18, 0.14)), t)
        A.tube(f"stitch{k}", [c + Vector((0.03, 0, -0.07)), c + Vector((0.03, 0, 0.07))], 0.012, M("scar"))


def build_spider():
    A = Acc("spider")
    A.obj("abdomen", bm_sphere(0.3), [M("spider")], loc=(0.05, 0.24, 1.2), scale=(1, 1.15, 0.85), subd=1)
    A.obj("thorax", bm_sphere(0.19), [M("spider")], loc=(0.05, -0.12, 1.17), subd=1)
    A.obj("spot", bm_sphere(0.09), [M("ruby")], loc=(0.05, 0.26, 1.45), scale=(1, 1.3, 0.35), subd=1)
    A.obj("eyes", bm_spheres([((0.05 + sx * 0.075, -0.27, 1.25), 0.07) for sx in (-1, 1)]), [M("eyeWhite")], subd=1)
    A.obj("pupils", bm_spheres([((0.05 + sx * 0.075, -0.33, 1.24), 0.035) for sx in (-1, 1)]), [M("pupil")])
    for sx in (-1, 1):
        for k in range(4):
            yk = -0.2 + k * 0.12
            start = Vector((0.05 + sx * 0.12, yk * 0.6 - 0.08, 1.18))
            knee = Vector((0.05 + sx * (0.42 + 0.05 * abs(k - 1.5)), yk * 1.7, 1.42))
            foot = Vector((sx * 0.62, yk * 2.4, 0.75)).normalized() * 1.0
            mid = (knee + foot) / 2 + (foot.normalized() * 0.1)
            A.tube(f"leg{sx}{k}", [start, knee, mid, foot], [0.035, 0.032, 0.026, 0.016], M("spider"))


def build_fangs():
    A = Acc("fangs")
    for sx in (-1, 1):
        A.tube(f"fang{sx}", [(sx * 0.13, -0.99, -0.14), (sx * 0.14, -1.02, -0.28), (sx * 0.12, -1.0, -0.44)],
               [0.075, 0.05, 0.005], M("fang"))
    A.tube("lip", [(-0.22, -0.97, -0.12), (0, -1.0, -0.15), (0.22, -0.97, -0.12)], 0.035, M("scar"))


def build_witchnose():
    A = Acc("witchnose")
    A.tube("nose", [(0, -0.95, 0.12), (0, -1.2, 0.05), (0, -1.45, -0.08), (0, -1.64, -0.1), (0, -1.74, 0.02)],
           [0.17, 0.14, 0.095, 0.065, 0.04], M("witchNose"))
    A.obj("warts", bm_spheres([((0.1, -1.22, 0.15), 0.045), ((-0.07, -1.47, 0.0), 0.035), ((0.04, -1.08, 0.24), 0.03)]),
          [M("wart")])


# --- Registry -------------------------------------------------------------------------

ITEMS = [
    ("cap", "hat", build_cap), ("party", "hat", build_party), ("beanie", "hat", build_beanie),
    ("cowboy", "hat", build_cowboy), ("headphones", "hat", build_headphones), ("chef", "hat", build_chef),
    ("bunny", "hat", build_bunny), ("crown", "hat", build_crown), ("wizard", "hat", build_wizard),
    ("viking", "hat", build_viking), ("pirate", "hat", build_pirate), ("tophat", "hat", build_tophat),
    ("halo", "hat", build_halo), ("unicorn", "hat", build_unicorn), ("propeller", "hat", build_propeller),
    ("shades", "face", build_shades), ("mustache", "face", build_mustache), ("clown", "face", build_clown),
    ("glasses", "face", build_glasses), ("heart", "face", build_heart), ("monocle", "face", build_monocle),
    ("eyepatch", "face", build_eyepatch),
    ("witch", "hat", build_witch), ("pumpkin", "hat", build_pumpkin), ("devil", "hat", build_devil),
    ("cat", "hat", build_cat), ("mummy", "hat", build_mummy), ("frankenstein", "hat", build_frankenstein),
    ("spider", "hat", build_spider), ("fangs", "face", build_fangs), ("witchnose", "face", build_witchnose),
]
SLOTS = {i: s for i, s, _ in ITEMS}
BUILDERS = {i: b for i, _, b in ITEMS}


def build(*ids):
    scene()
    for i in ids:
        BUILDERS[i]()


def build_all():
    build(*BUILDERS.keys())


# --- Thumbnails & export --------------------------------------------------------------

def studio_light():
    for name, energy in (("TW_Key", 240), ("TW_Fill", 90), ("TW_Rim", 200)):
        if name in bpy.data.objects:
            bpy.data.objects[name].data.energy = energy
    scn = scene()
    bg = scn.world.node_tree.nodes.get("Background") if scn.world else None
    if bg:
        bg.inputs[1].default_value = 0.2
    scn.view_settings.view_transform = "Standard"


def render_thumbnails(ids=None, outdir=MODELS, size=256, prefix="thumb_"):
    scn = scene()
    studio_light()
    ids = list(ids or BUILDERS.keys())
    cam = bpy.data.objects["TW_Cam"]
    scn.camera = cam
    scn.render.resolution_x = scn.render.resolution_y = size
    accs = [c for c in scn.collection.children if c.name.startswith("acc_")]
    view = Vector((0.38, -1.0, 0.3)).normalized()
    for id_ in ids:
        for c in accs:
            c.hide_render = c.name != "acc_" + id_
        dg = bpy.context.evaluated_depsgraph_get()
        dg.update()
        pts = []
        for o in bpy.data.collections["acc_" + id_].all_objects:
            if o.type == "MESH":
                oe = o.evaluated_get(dg)
                pts += [oe.matrix_world @ Vector(c) for c in oe.bound_box]
        if SLOTS[id_] == "hat":
            pts += [Vector(p) for p in [(0.8, 0, 0.45), (-0.8, 0, 0.45), (0, -0.95, 0.4)]]
        else:
            pts += [Vector(p) for p in [(0.9, -0.5, -0.45), (-0.9, -0.5, -0.45), (0, -0.9, 0.95)]]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        center = (lo + hi) / 2
        radius = (hi - lo).length / 2
        dist = radius / sin(cam.data.angle / 2) * 0.92
        cam.location = center + view * dist
        cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
        scn.render.filepath = f"{outdir}/{prefix}{id_}.png"
        bpy.ops.render.render(write_still=True)
    for c in accs:
        c.hide_render = False


def export_all(ids=None):
    from pxr import Usd
    scn = scene()
    vl = bpy.context.view_layer
    report = {}
    for id_ in (ids or BUILDERS.keys()):
        bpy.ops.object.select_all(action="DESELECT")
        for o in bpy.data.collections["acc_" + id_].all_objects:
            o.select_set(True)
        vl.objects.active = bpy.data.objects["acc_" + id_]
        path = f"{MODELS}/{id_}.usdz"
        bpy.ops.wm.usd_export(filepath=path, selected_objects_only=True, export_materials=True,
                              export_subdivision="TESSELLATE", convert_orientation=True,
                              export_global_forward_selection="NEGATIVE_Z", export_global_up_selection="Y",
                              convert_world_material=False, root_prim_path="/" + id_)
        Usd.Stage.Open(path)
        report[id_] = os.path.getsize(path)
    return report
