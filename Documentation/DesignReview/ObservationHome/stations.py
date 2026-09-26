"""Render low-poly glass icons of the ISS and Tiangong for the pass list.

Run: Blender -b -P stations.py -- <out_dir>
Produces <out_dir>/station-iss.png and <out_dir>/station-tiangong.png at 512 px with alpha.
"""
import math
import sys

import bpy
from mathutils import Vector

OUT = sys.argv[sys.argv.index("--") + 1]


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def glass(name, tint, rim, strength, transmission=0.85):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = (*tint, 1)
    bsdf.inputs["Roughness"].default_value = 0.18
    bsdf.inputs["Transmission Weight"].default_value = transmission
    bsdf.inputs["IOR"].default_value = 1.35
    bsdf.inputs["Alpha"].default_value = 0.92
    bsdf.inputs["Specular IOR Level"].default_value = 0.7
    # Fresnel-driven rim glow keeps the silhouette readable at 22 pt.
    layer = nodes.new("ShaderNodeLayerWeight")
    layer.inputs["Blend"].default_value = 0.35
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
    ramp.color_ramp.elements[1].position = 1.0
    ramp.color_ramp.elements[1].color = (*rim, 1)
    links.new(layer.outputs["Facing"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = strength
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    mat.blend_method = "BLEND"
    return mat


def add(kind, name, loc, scale, rot=(0, 0, 0), mat=None, **kw):
    if kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("verts", 8), radius=1, depth=1, location=loc)
    elif kind == "box":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("verts", 8), radius1=1, radius2=kw.get("r2", 0.5), depth=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    obj.rotation_euler = [math.radians(r) for r in rot]
    if kw.get("bevel"):
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = kw["bevel"]
        mod.segments = 1
    obj.data.materials.append(mat)
    return obj


def iss(body, panel):
    # Integrated truss along X with paired solar wings at each end (S6/P6 outer, S4/P4 inner).
    add("box", "truss", (0, 0, 0), (11.4, 0.55, 0.55), mat=body, bevel=0.08)
    for x in (-4.7, 4.7, -2.5, 2.5):
        for y in (1, -1):
            add("box", f"wing{x}{y}", (x, y * 2.6, 0), (1.9, 3.7, 0.09), mat=panel, bevel=0.03)
    # Heat rejection radiators on S1/P1 hang perpendicular to the arrays, giving the station depth.
    for x in (-0.8, 0.8, -1.75, 1.75):
        add("box", f"rad{x}", (x, 0.6, -1.9), (0.85, 0.06, 3.0), mat=panel, bevel=0.02)
    # Pressurized modules run along Y below the truss centre; labs cross them.
    add("cyl", "core", (0, -1.4, -1.25), (0.62, 0.62, 5.6), rot=(90, 0, 0), mat=body, verts=10, bevel=0.06)
    add("cyl", "node", (0, 1.5, -1.25), (0.72, 0.72, 0.9), rot=(90, 0, 0), mat=body, verts=10, bevel=0.06)
    add("cyl", "node2", (0, -4.3, -1.25), (0.72, 0.72, 0.9), rot=(90, 0, 0), mat=body, verts=10, bevel=0.06)
    add("cyl", "lab", (1.5, -2.2, -1.25), (0.55, 0.55, 2.0), rot=(0, 90, 0), mat=body, verts=10, bevel=0.05)
    add("cyl", "lab2", (-1.5, -2.2, -1.25), (0.55, 0.55, 2.0), rot=(0, 90, 0), mat=body, verts=10, bevel=0.05)
    add("cyl", "mast", (0, 0, -0.65), (0.35, 0.35, 1.3), mat=body, verts=8)


def tiangong(body, panel):
    # Tianhe core stem along -Y from the forward node; labs form the crossbar along X.
    add("cyl", "tianhe", (0, -2.3, 0), (0.78, 0.78, 4.6), rot=(90, 0, 0), mat=body, verts=10, bevel=0.07)
    add("cone", "tail", (0, -4.9, 0), (0.78, 0.78, 0.7), rot=(90, 0, 0), mat=body, verts=10, r2=0.55)
    add("cyl", "node", (0, 0.35, 0), (0.95, 0.95, 1.15), rot=(90, 0, 0), mat=body, verts=10, bevel=0.08)
    for x in (-1, 1):
        add("cyl", f"lab{x}", (x * 2.6, 0.35, 0), (0.62, 0.62, 4.2), rot=(0, 90, 0), mat=body, verts=10, bevel=0.06)
        for y in (1, -1):
            add("box", f"wing{x}{y}", (x * 4.75, 0.35 + y * 3.6, 0), (1.5, 5.6, 0.1), mat=panel, bevel=0.03)
    for y in (1, -1):
        add("box", f"corewing{y}", (y * 2.1, -3.9, 0), (2.8, 1.1, 0.1), mat=panel, bevel=0.03)


def scene(name, build, body_tint, panel_tint, rim, panel_transmission=0.45, panel_glow=3.0):
    clear()
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE_NEXT"
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = 512
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    sc.eevee.taa_render_samples = 64
    body = glass(f"{name}-body", body_tint, rim, 2.4)
    panel = glass(f"{name}-panel", panel_tint, rim, panel_glow, transmission=panel_transmission)
    build(body, panel)
    # World: dim cool ambient so glass refracts something.
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.05, 0.09, 0.14, 1)
    bg.inputs[1].default_value = 1.0
    # Key and fill area lights for broad glassy highlights.
    for loc, energy, col in (((6, -8, 10), 2500, (1, 1, 1)), ((-8, 6, 6), 900, (*rim, 1)), ((0, 8, -4), 500, (0.8, 0.9, 1, 1))):
        bpy.ops.object.light_add(type="AREA", location=loc)
        light = bpy.context.active_object
        light.data.energy = energy
        light.data.size = 8
        light.data.color = col[:3]
        light.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    # Elevated three-quarter orthographic camera, whole station with margin.
    bpy.ops.object.camera_add(location=(8, -11, 9))
    cam = bpy.context.active_object
    cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 15.5
    sc.camera = cam
    sc.render.filepath = f"{OUT}/station-{name}.png"
    bpy.ops.render.render(write_still=True)


scene("iss", iss, (0.75, 0.96, 0.94), (0.30, 0.78, 0.76), (0.44, 0.90, 0.86))
scene("tiangong", tiangong, (1.0, 0.92, 0.86), (1.0, 0.66, 0.46), (1.0, 0.72, 0.56), panel_transmission=0.12, panel_glow=4.5)
print("rendered")
