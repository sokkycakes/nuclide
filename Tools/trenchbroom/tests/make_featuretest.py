"""Writes tests/featuretest.map, a feature test map in TrenchBroom's Quake 3 (legacy) format: python3 make_featuretest.py featuretest.map"""
import sys
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def face(normal, d, mat, sc=0.5):
    ax = [i for i in range(3) if normal[i] == 0]
    u = [0, 0, 0]; v = [0, 0, 0]; u[ax[0]] = 64; v[ax[1]] = 64
    if cross(v, u) != tuple(4096*n for n in normal): u, v = v, u
    p1 = [0, 0, 0]; k = [i for i in range(3) if normal[i]][0]; p1[k] = d
    p2 = [p1[i]+u[i] for i in range(3)]; p3 = [p1[i]+v[i] for i in range(3)]
    f = lambda p: "( %d %d %d )" % tuple(p)
    return "%s %s %s %s 0 0 0 %s %s %d 0 0" % (f(p1), f(p2), f(p3), mat, sc, sc, CONTENTS)
CONTENTS = 0
def box(mins, maxs, mat="measure/wall64", faces=None, contents=0):
    global CONTENTS; CONTENTS = contents
    """faces: {"+x": mat, "-z": mat, ...}; others get mat"""
    faces = faces or {}
    out = ["{"]
    for k, a in enumerate("xyz"):
        for sgn, d in ((-1, mins[k]), (1, maxs[k])):
            n = [0, 0, 0]; n[k] = sgn
            out.append(face(tuple(n), d, faces.get(("+" if sgn > 0 else "-") + a, mat)))
    out.append("}")
    return "\n".join(out)
def patch(mat, rows):
    out = ["{", "patchDef2", "{", mat, "( %d %d 0 0 0 )" % (len(rows), len(rows[0])), "("]
    for r in rows:
        out.append("( " + " ".join("( %g %g %g %g %g )" % p for p in r) + " )")
    out += [")", "}", "}"]
    return "\n".join(out)
def ent(props, brushes=()):
    out = ["{"] + ['"%s" "%s"' % kv for kv in props.items()] + list(brushes) + ["}"]
    return "\n".join(out)

C = "common/caulk"
W = "measure/wall64"
world = []
# shell: x -528..544, y -272..272, z -16..272; interior x -512..528, y -256..256, z 0..256
world.append(box((-528, -272, -16), (544, 272, 0), C, {"+z": "measure/floor"}))
world.append(box((-528, -272, 256), (0, 272, 272), C, {"-z": "measure/ceiling"}))      # room A ceiling
world.append(box((0, -272, 256), (544, 272, 272), C, {"-z": "common/skyportal"}))      # room B: sky
world.append(box((-528, -256, 0), (-512, 256, 256), C, {"+x": W}))
world.append(box((528, -256, 0), (544, 256, 256), C, {"-x": W}))
world.append(box((-528, -272, 0), (544, -256, 256), C, {"+y": W}))
world.append(box((-528, 256, 0), (544, 272, 256), C, {"-y": W}))
# partition with a doorway at y -64..64, z 0..128
world.append(box((0, -256, 0), (16, -64, 256), W))
world.append(box((0, 64, 0), (16, 256, 256), W))
world.append(box((0, -64, 128), (16, 64, 256), W))
# stairs and a ledge in room A
for i in range(4):
    world.append(box((-384 + i*32, 160, 0), (-352 + i*32, 256, 16*(i+1)), "measure/stairs1"))
world.append(box((-256, 160, 0), (-128, 256, 64), "measure/wall128"))
# hint brush across the doorway
world.append(box((-8, -64, 0), (-4, 64, 128), "common/hint", {"+x": "common/skip", "-x": "common/hint"}))
# clip brush along the stairs
world.append(box((-384, 152, 0), (-256, 160, 64), "common/clip"))
# a patch arch over the room A floor (3x3 bend)
world.append(patch("measure/wall128", [
    [(-320, -160, 0, 0, 0), (-320, -160, 96, 0, 0.5), (-320, -96, 96, 0, 1)],
    [(-288, -160, 0, 0.5, 0), (-288, -160, 96, 0.5, 0.5), (-288, -96, 96, 0.5, 1)],
    [(-256, -160, 0, 1, 0), (-256, -160, 96, 1, 0.5), (-256, -96, 96, 1, 1)],
]))

world.append(box((-80, 120, 0), (-48, 152, 256), "measure/wall32", contents=134217728))  # Detail content flag

ents = []
ents.append(ent({"classname": "worldspawn", "message": "TrenchBroom feature test", "skyname": "dune", "_ambient": "10"}, world))
ents.append(ent({"classname": "info_player_start", "origin": "-448 0 40", "angle": "0"}))
ents.append(ent({"classname": "info_player_deathmatch", "origin": "-448 -128 40", "angle": "0"}))
ents.append(ent({"classname": "info_player_deathmatch", "origin": "448 128 40", "angle": "180"}))
for o, c in (("-256 0 200", "1 0.9 0.8"), ("-448 128 200", "0.8 0.9 1"), ("256 0 200", "1 1 1"), ("448 -160 120", "1 0.6 0.3")):
    ents.append(ent({"classname": "light", "origin": o, "light": "300", "_color": c}))
ents.append(ent({"classname": "light", "origin": "256 160 96", "light": "200", "targetname": "lamp1", "_color": "0.3 1 0.3"}))
# door + button
ents.append(ent({"classname": "func_door", "targetname": "door1", "angle": "-1", "lip": "8", "wait": "4", "speed": "100",
                 "OnFullyOpen": "lamp1,Toggle,,0,-1"},
                [box((4, -64, 0), (12, 64, 128), "measure/door")]))
ents.append(ent({"classname": "func_button", "target": "door1", "angle": "180", "lip": "2", "wait": "1"},
                [box((-512, -24, 48), (-504, 24, 80), "measure/mat_metal")]))
# trigger -> logic_relay -> light toggle
ents.append(ent({"classname": "trigger_multiple", "wait": "1", "OnTrigger": "relay1,Trigger,,0,-1"},
                [box((160, -96, 0), (288, 96, 64), "common/trigger")]))
ents.append(ent({"classname": "logic_relay", "targetname": "relay1", "origin": "224 0 96", "OnTrigger": "lamp1,Toggle,,0.5,-1"}))
# teleporter A -> B
ents.append(ent({"classname": "trigger_teleport", "target": "tele_dest"},
                [box((-512, -256, 0), (-448, -192, 64), "common/trigger")]))
ents.append(ent({"classname": "info_teleport_destination", "targetname": "tele_dest", "origin": "448 0 32", "angle": "180"}))
# push pad
ents.append(ent({"classname": "trigger_push", "angles": "-80 0 0", "speed": "600"},
                [box((-160, -64, 0), (-96, 0, 16), "common/trigger")]))
# rotating fan with origin brush
ents.append(ent({"classname": "func_rotating", "speed": "60", "spawnflags": "1"},
                [box((384, -176, 120), (480, -144, 128), "measure/mat_metal"),
                 box((424, -168, 116), (440, -152, 132), "common/origin")]))
# platform
ents.append(ent({"classname": "func_plat", "height": "96", "speed": "100"},
                [box((320, 128, 0), (448, 240, 8), "measure/mat_metal")]))
# breakable crate, detail pillar, func_wall
ents.append(ent({"classname": "func_breakable", "material": "1", "health": "20"},
                [box((96, -224, 0), (144, -176, 48), "measure/mat_wood")]))
ents.append(ent({"classname": "func_wall"},
                [box((96, 176, 0), (112, 240, 96), "measure/mat_glass")]))
# a group (as TrenchBroom writes groups) and a ladder
ents.append(ent({"classname": "func_group", "_tb_type": "_tb_group", "_tb_name": "crates", "_tb_id": "1"},
                [box((-200, -240, 0), (-168, -208, 32), "measure/mat_wood"),
                 box((-200, -240, 32), (-168, -208, 64), "measure/mat_wood")]))
ents.append(ent({"classname": "func_ladder"}, [box((-512, 64, 0), (-500, 112, 192), "common/clip")]))
# pickups and a sound
ents.append(ent({"classname": "item_health", "origin": "-320 64 16"}))
ents.append(ent({"classname": "weapon_shotgun", "origin": "-320 -32 16"}))
ents.append(ent({"classname": "ambient_generic", "origin": "448 -160 160", "message": "ambience/comp1.wav", "health": "5", "spawnflags": "2"}))
open(sys.argv[1], "w", newline="\n").write("// Game: test\n// Format: Quake3 (legacy)\n" + "\n".join("// entity %d\n%s" % (i, e) for i, e in enumerate(ents)) + "\n")
