#!/usr/bin/env python3
"""Builds the TrenchBroom entity definitions for Bulwark and Stiletto Proto.

Every map entity the games can spawn comes from one pool:

  * QuakeC classes documented with /*!QUAKED ... */ blocks (Nuclide's
    src/gs-entbase, src/shared, src/server, and a game's own src/),
  * entityDef declarations under a game's decls/def/ (an entityDef can be
    placed in a map like a class; its spawnclass gives it the class's keys),
  * scripted entities, scripts/vscripts/entities/<classname>.lua, which
    Bulwark's ncScriptedEntity spawns for classnames that have no QC class.

This script reads all three and writes one self-contained FGD per entity
definition file listed in PROFILES, with the hand-written pieces under
shared/ (compiler keys, engine keys, script hooks) folded in. The FGDs are
written into games/<profile>/ next to the GameConfig.cfg that names them.

Usage (paths are checkouts on your machine; any that are missing are
skipped, and the profiles that need them keep their committed FGDs):

  python3 build_fgd.py \
      --framework ~/src/nuclide-framework   # Nuclide with the script hooks
      --stiletto  ~/src/nuclide-stiletto    # Nuclide with Stiletto's base/
      --coop      ~/src/bulwark-engine/games/coop

--valve defaults to <framework>/valve (Rad-Therapy). Python 3.8 or newer,
standard library only.
"""

import argparse
import copy
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SHARED = os.path.join(HERE, "shared")
GAMES = os.path.join(HERE, "games")

# Layers are read in order; a class in a later layer replaces an earlier one
# of the same name. "shared:<file>" is a hand-written FGD under shared/.
SIMPLE = ["shared:io.fgd", "shared:compile-simple.fgd"]
COMPAT = ["shared:io.fgd", "shared:compile-compat.fgd"]

# "simple" profiles leave out the nc* QuakeC base classes, which can't be
# placed on their own, and use the short compiler key set.
PROFILES = [
    {
        "dir": "Bulwark",
        "scripting": True,
        "simple": True,
        "files": [
            ("Bulwark.fgd", "Bulwark",
             SIMPLE + ["shared:bulwark.fgd", "nuclide:framework",
                       "shared:compile-entities-simple.fgd"]),
        ],
    },
    {
        "dir": "Stiletto Proto (Bulwark)",
        "scripting": True,
        "simple": True,
        "files": [
            ("Stiletto.fgd", "Stiletto Proto on Bulwark",
             SIMPLE + ["shared:bulwark.fgd", "nuclide:stiletto", "game:stiletto",
                       "shared:compile-entities-simple.fgd"]),
        ],
    },
    {
        "dir": "Stiletto Proto (FTEQW)",
        "scripting": False,
        "simple": True,
        "files": [
            ("Stiletto.fgd", "Stiletto Proto on FTEQW",
             SIMPLE + ["nuclide:stiletto", "game:stiletto",
                       "shared:compile-entities-simple.fgd"]),
        ],
    },
    {
        "dir": "Bulwark Compat",
        "scripting": True,
        "files": [
            ("Bulwark-Compat.fgd", "Bulwark Compat: Nuclide framework entities",
             COMPAT + ["shared:bulwark.fgd", "nuclide:framework",
                       "shared:compile-entities-compat.fgd"]),
            ("Bulwark-Compat-HalfLife.fgd", "Bulwark Compat: Half-Life (Rad-Therapy) and Sven Co-op style co-op",
             COMPAT + ["shared:bulwark.fgd", "nuclide:framework",
                       "game:valve", "game:coop", "shared:compile-entities-compat.fgd"]),
        ],
    },
    {
        "dir": "Stiletto Proto Compat (Bulwark)",
        "scripting": True,
        "files": [
            ("Stiletto-Compat.fgd", "Stiletto Proto Compat on Bulwark",
             COMPAT + ["shared:bulwark.fgd", "nuclide:stiletto",
                       "game:stiletto", "shared:compile-entities-compat.fgd"]),
        ],
    },
    {
        "dir": "Stiletto Proto Compat (FTEQW)",
        "scripting": False,
        "files": [
            ("Stiletto-Compat.fgd", "Stiletto Proto Compat on FTEQW",
             COMPAT + ["nuclide:stiletto",
                       "game:stiletto", "shared:compile-entities-compat.fgd"]),
        ],
    },
]

# Notes added to a class's description, for things a mapper trips over.
NOTES = {
    "func_detail": "Compiler note: Nuclide's vmap merges func_detail into the world, but q3map2 leaves it as a brush model with no game class, so it disappears in game. With q3map2, use the Detail content flag (Face inspector) on world brushes instead.",
    "func_detail_illusionary": "Compiler note: needs Nuclide's vmap; q3map2 leaves it as a brush model with no game class.",
}

# entityDefs that are data tables, attacks or characters rather than map entities
DEF_SKIP_PREFIXES = (
    "projectile_", "damage_", "melee_", "ranged_", "fireInfo_", "fireinfo_",
    "debris_", "hero_", "attack_", "flame_damage", "ammo_types", "ammo_names",
    "ammo_max", "player", "islave_", "domination_icon", "domination_team",
)
TARGET_KEYS = {
    "target", "killtarget", "master", "parentname", "pathtarget", "altpath",
    "target1", "target2", "target3", "target4", "deathtarget", "triggertarget",
    "trigger_target", "combinetarget", "filtername", "damagefilter", "lightingorigin",
    "attach1", "attach2", "LightingOrigin", "m_iszEntity", "netname_target",
}
COLOR255_KEYS = {"rendercolor", "_light", "_lighthdr", "color255", "lightcolor",
                 "_ambient255", "fogcolor", "fogcolor2", "_sunlight_color255"}
COLOR1_KEYS = {"_color", "color", "_sunlight_color", "_sunlight2_color", "_ambient"}
MODEL_CLASSES_FROM_KEY = (
    "prop_", "cycler", "env_model", "env_sprite", "env_glow", "monster_generic",
    "monster_furniture", "npc_furniture", "item_generic", "script_model",
    "func_dustmotes", "misc_model", "env_beverage",
)


# ---------------------------------------------------------------- utilities

def clean(text):
    """One line of FGD-safe text."""
    text = text.replace("\\", "/").replace('"', "'")
    text = re.sub(r"\s+", " ", text).strip()
    return text


def fgd_str(text):
    return '"' + clean(text) + '"'


def color255(rgb):
    out = []
    for v in rgb:
        try:
            f = float(v)
        except ValueError:
            f = 0.5
        out.append(str(int(round(max(0.0, min(1.0, f)) * 255))))
    return " ".join(out)


def read(path):
    with open(path, "r", encoding="utf-8", errors="replace") as fh:
        return fh.read()


def humanize(key):
    k = key.lstrip("_")
    k = re.sub(r"([a-z])([A-Z])", r"\1 \2", k).replace("_", " ")
    return k[:1].upper() + k[1:] if k else key


# ---------------------------------------------------------------- model

class Prop:
    def __init__(self, key, desc="", kind="string", default="", choices=None,
                 label=None):
        self.key = key
        self.desc = desc
        self.kind = kind          # string, integer, float, choices, color1, color255,
                                  # target_source, target_destination
        self.default = default
        self.choices = choices or []
        self.label = label


class EntClass:
    def __init__(self, name):
        self.name = name
        self.solid = False
        self.color = None
        self.size = None
        self.desc = ""
        self.props = []           # list of Prop, in order
        self.flags = {}           # bit -> (caption, description)
        self.inputs = []          # (name, type, desc)
        self.outputs = []
        self.model = None         # FGD model expression, without model(...)
        self.bases = []
        self.source = ""
        self.def_base = None

    def prop(self, key):
        for p in self.props:
            if p.key.lower() == key.lower():
                return p
        return None

    def add_prop(self, p):
        if p.key.lower() == "spawnflags":
            return
        if not self.prop(p.key):
            self.props.append(p)

    def add_io(self, which, name, kind, desc):
        lst = self.inputs if which == "input" else self.outputs
        for existing in lst:
            if existing[0].lower() == name.lower():
                return
        lst.append((name, kind, desc))


# ---------------------------------------------------------------- QUAKED

QUAKED_RE = re.compile(r"/\*!?QUAKED\s+(.*?)\*/", re.S)
HEAD_RE = re.compile(
    r"^(\S+)\s*\(([^)]*)\)\s*(\?|\(([^)]*)\)\s*\(([^)]*)\))?\s*(.*)$")
ITEM_RE = re.compile(r'^-\s*"([^"]+)"\s*(?::|-)\s*(.*)$')
FLAG_RE = re.compile(r"^-\s*([A-Za-z0-9_]+)\s*\(\s*(\d+)\s*\)\s*:?\s*(.*)$")
TYPED_IO_RE = re.compile(r"^\((void|string|integer|float|bool|boolean|ehandle|int|vector)\)\s*(.*)$", re.I)


def parse_quaked_block(body, source):
    lines = body.splitlines()
    if not lines:
        return None
    m = HEAD_RE.match(lines[0].strip())
    if not m:
        return None
    ent = EntClass(m.group(1))
    ent.source = source
    ent.color = color255(m.group(2).split())
    if m.group(3) == "?":
        ent.solid = True
    elif m.group(3):
        ent.size = (m.group(4).strip(), m.group(5).strip())
    header_flags = m.group(6).split()
    for i, name in enumerate(header_flags):
        if name.lower() not in ("x", "-", "?", "unused") and i < 24:
            ent.flags[1 << i] = (name, "")

    section = "OVERVIEW"
    overview, notes = [], []
    last = None
    for raw in lines[1:]:
        line = raw.rstrip()
        s = line.strip()
        if s.startswith("@ingroup") or s.startswith("-------- MODEL FOR RADIANT"):
            continue
        mm = re.match(r'^model\s*=\s*"([^"]+)"', s)
        if mm:
            ent.model = '"%s"' % clean(mm.group(1))
            continue
        h = re.match(r"^#\s+([A-Z][A-Z ()]*)$", s)
        if h:
            section = h.group(1).strip()
            last = None
            continue
        if section.startswith("KEYS"):
            im = ITEM_RE.match(s)
            if im:
                last = Prop(im.group(1), im.group(2))
                ent.add_prop(last)
            elif last is not None and s:
                cm = re.match(r"^(-?\d+)\s*=\s*(.+)$", s)
                if cm:
                    last.choices.append((cm.group(1), cm.group(2)))
                else:
                    last.desc += " " + s
        elif section.startswith("INPUTS") or section.startswith("OUTPUTS"):
            im = ITEM_RE.match(s)
            if im:
                kind, desc = "void", im.group(2)
                tm = TYPED_IO_RE.match(desc)
                if tm:
                    kind, desc = tm.group(1).lower(), tm.group(2)
                    kind = {"int": "integer", "vector": "string"}.get(kind, kind)
                elif re.search(r"\bdata\b|\bvalue\b|in seconds|\bnumber\b|\bamount\b", desc, re.I) \
                        and section.startswith("INPUTS"):
                    kind = "string"
                ent.add_io("input" if section.startswith("INPUTS") else "output",
                           im.group(1), kind, desc)
        elif section.startswith("SPAWNFLAGS"):
            fm = FLAG_RE.match(s)
            if fm:
                bit = int(fm.group(2))
                if bit in ent.flags and section != "SPAWNFLAGS":
                    cap, d = ent.flags[bit]
                    ent.flags[bit] = (cap, (d + " Legacy " + fm.group(1) + ": " + fm.group(3)).strip())
                elif bit in ent.flags and ent.flags[bit][1] and section != "SPAWNFLAGS":
                    pass
                else:
                    ent.flags[bit] = (fm.group(1), fm.group(3))
        elif section == "OVERVIEW":
            overview.append(s)
        elif section == "NOTES":
            notes.append(s)
    text = " ".join(x for x in overview if x)
    if notes:
        text += "  Notes: " + " ".join(x for x in notes if x)
    ent.desc = text
    return ent


def scan_quaked(roots, label):
    classes = {}
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames.sort()
            for fn in sorted(filenames):
                if not fn.endswith((".qc", ".h", ".qh")):
                    continue
                path = os.path.join(dirpath, fn)
                for m in QUAKED_RE.finditer(read(path)):
                    ent = parse_quaked_block(m.group(1), label)
                    if ent and ent.name not in classes:
                        classes[ent.name] = ent
    return classes


# ---------------------------------------------------------------- entityDef

def tokenize_decl(text):
    text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
    toks = []
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("#"):
            continue
        i = 0
        while i < len(s):
            c = s[i]
            if s.startswith("//", i):
                break
            if c.isspace():
                i += 1
            elif c == '"':
                j = s.find('"', i + 1)
                j = len(s) if j < 0 else j
                toks.append(("s", s[i + 1:j]))
                i = j + 1
            elif c in "{}":
                toks.append((c, c))
                i += 1
            else:
                j = i
                while j < len(s) and not s[j].isspace() and s[j] not in '{}"':
                    j += 1
                toks.append(("w", s[i:j]))
                i = j
    return toks


def parse_decls(root):
    """Returns {name: {key: value}} for every entityDef under root."""
    defs = {}
    if not os.path.isdir(root):
        return defs
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for fn in sorted(filenames):
            if not fn.endswith(".def"):
                continue
            toks = tokenize_decl(read(os.path.join(dirpath, fn)))
            i = 0
            while i < len(toks):
                if toks[i] == ("w", "entityDef") and i + 2 < len(toks):
                    name = toks[i + 1][1]
                    i += 2
                    if toks[i][0] != "{":
                        continue
                    depth, i = 1, i + 1
                    keys = {}
                    while i < len(toks) and depth:
                        t = toks[i]
                        if t[0] == "{":
                            depth += 1
                        elif t[0] == "}":
                            depth -= 1
                        elif depth == 1 and t[0] in "sw" and i + 1 < len(toks) \
                                and toks[i + 1][0] in "sw":
                            keys.setdefault(t[1], toks[i + 1][1])
                            i += 1
                        i += 1
                    defs[name] = keys
                else:
                    i += 1
    return defs


def resolve_def(name, defs, seen=None):
    seen = seen or set()
    if name in seen or name not in defs:
        return {}
    seen.add(name)
    keys = dict(defs[name])
    parent = keys.get("inherit")
    if parent:
        merged = resolve_def(parent, defs, seen)
        merged.update(keys)
        keys = merged
    return keys


CLASS_DECL_RE = re.compile(r"\bclass\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([A-Za-z_][A-Za-z0-9_]*)")


def scan_parents(roots):
    """QC class -> parent class, from 'class Child:Parent' declarations."""
    parents = {}
    for root in roots:
        if not os.path.isdir(root):
            continue
        for dirpath, dirnames, filenames in os.walk(root):
            for fn in filenames:
                if fn.endswith((".qc", ".h", ".qh")):
                    for m in CLASS_DECL_RE.finditer(read(os.path.join(dirpath, fn))):
                        parents.setdefault(m.group(1), m.group(2))
    return parents


def documented_ancestor(name, qc, parents):
    seen = set()
    while name and name not in seen:
        if name in qc:
            return qc[name]
        seen.add(name)
        name = parents.get(name)
    return None


def defs_to_classes(defs, qc, parents):
    """entityDefs that can be placed in a map. Each one inherits the keys of the
    nearest documented QC class it spawns as, through a Def_<class> base."""
    out = {}
    for name in defs:
        if name.startswith(DEF_SKIP_PREFIXES) or name.endswith("_base"):
            continue
        keys = resolve_def(name, defs)
        spawnclass = keys.get("spawnclass", "")
        editor = any(k.startswith("editor_") for k in keys)
        if not spawnclass and not editor and name not in qc:
            continue
        base_ent = qc.get(name) if name in qc else documented_ancestor(spawnclass, qc, parents)
        ent = EntClass(name)
        ent.source = "entityDef"
        if base_ent:
            ent.solid = base_ent.solid
            ent.color = base_ent.color
            ent.size = base_ent.size
            ent.model = base_ent.model
            ent.def_base = base_ent.name
        if "editor_color" in keys:
            ent.color = color255(keys["editor_color"].split())
        mins = keys.get("editor_mins") or keys.get("mins")
        maxs = keys.get("editor_maxs") or keys.get("maxs")
        if mins and maxs and mins != "?":
            ent.size = (mins, maxs)
            ent.solid = False
        elif mins == "?":
            ent.solid = True
        ent.color = ent.color or "200 200 200"
        if not ent.solid and not ent.size:
            ent.size = ("-16 -16 -16", "16 16 16")
        model = keys.get("editor_model") or keys.get("model")
        if model and not ent.solid and not model.startswith("*"):
            ent.model = '"%s"' % clean(model)
        usage = keys.get("editor_usage") or keys.get("editor_description") \
            or keys.get("netname") or ""
        parts = []
        if usage:
            parts.append(usage.rstrip(".") + ".")
        chain = spawnclass or (base_ent.name if base_ent else "")
        parts.append("entityDef%s%s." % (
            " spawned as " + chain if chain else "",
            " (keys of " + base_ent.name + ")" if base_ent and base_ent.name != chain else ""))
        if base_ent and base_ent.desc:
            parts.append(base_ent.desc)
        ent.desc = " ".join(parts)
        out[name] = ent
    return out


# ---------------------------------------------------------------- Lua entities

def lua_classes(root):
    out = {}
    if not os.path.isdir(root):
        return out
    for fn in sorted(os.listdir(root)):
        if not fn.endswith((".lua", ".js")):
            continue
        name = os.path.splitext(fn)[0]
        comment = "--" if fn.endswith(".lua") else "//"
        header = []
        for line in read(os.path.join(root, fn)).splitlines():
            if not line.startswith(comment):
                break
            header.append(line[len(comment):])
        ent = EntClass(name)
        ent.source = "script"
        ent.color = "255 128 192"
        ent.size = ("-8 -8 -8", "8 8 8")
        desc, keys_done = [], False
        last = None
        for raw in header:
            s = raw.strip()
            km = re.match(r"^\s{2,}([A-Za-z_][A-Za-z0-9_, ]*?)\s{2,}(.+)$", raw)
            fm = re.match(r"^\s{2,}spawnflags\s+(\d+)\s+(.+)$", raw)
            if fm:
                bit = int(fm.group(1))
                ent.flags[bit] = (re.split(r"[:(]", fm.group(2))[0].strip()[:40], fm.group(2))
                last = None
            elif km:
                for k in re.split(r"[ ,]+", km.group(1).strip()):
                    if k and k not in ("render", "keys"):
                        last = Prop(k, km.group(2))
                        ent.add_prop(last)
            elif raw.startswith("    ") and last is not None and s:
                last.desc += " " + s
            elif s:
                desc.append(s)
                last = None
        text = " ".join(desc)
        ent.desc = text + "  Scripted entity: scripts/vscripts/entities/%s, spawned by" \
            " Bulwark's ncScriptedEntity when no QC class has this classname." % fn
        if not ent.prop("targetname"):
            ent.props.insert(0, Prop("targetname", "Name"))
        out[name] = ent
    return out


# ---------------------------------------------------------------- typing

def finish(ent, scripting):
    """Infers property types and attaches the shared base classes."""
    # every Nuclide entity reads targetname, documented or not; without it
    # TrenchBroom can't draw or check links to it (info_teleport_destination)
    if ent.name != "worldspawn" and not ent.prop("targetname"):
        ent.props.insert(0, Prop("targetname", "Name other entities use to target this one.", label="Name"))
    for p in ent.props:
        k = p.key.lower()
        if p.kind != "string":
            continue
        if k == "targetname":
            p.kind = "target_source"
        elif p.key in TARGET_KEYS or k in TARGET_KEYS or \
                re.match(r"^(name of (the )?)?target\b", p.desc.strip().lower()):
            p.kind = "target_destination"
        elif k in COLOR255_KEYS or "rgb255" in p.desc.lower().replace(" ", ""):
            p.kind = "color255"
        elif k in COLOR1_KEYS or "normalized rgb" in p.desc.lower():
            p.kind = "color1"
        elif p.choices:
            p.kind = "choices"
        elif re.search(r"\b(set to (either )?0 or 1|when set to 1|1 to |0/1|toggle)\b",
                       p.desc, re.I) or k.startswith("start") or k.startswith("disable"):
            p.kind = "choices"
            p.choices = [("0", "No"), ("1", "Yes")]
        m = re.search(r"[Dd]efault(?: value)? is ['\"`\[]([^'\"`\]]+)['\"`\]]", p.desc) or \
            re.search(r"[Dd]efault(?: value)? is (-?[0-9][0-9.]*[0-9]|-?[0-9])", p.desc)
        if m:
            p.default = m.group(1).strip()
    if ent.name == "worldspawn":
        ent.bases = ["WorldCompile", "WorldEngine"] + (["WorldBulwark"] if scripting else [])
    else:
        ent.bases.append("NuclideIO")
        if ent.solid:
            ent.bases.append("BrushCompile")
        if ent.name.startswith("light") and not ent.solid:
            ent.bases.append("LightCompile")
        if scripting:
            ent.bases.append("BulwarkScripted")
        if ent.def_base:
            ent.bases.append("Def_" + ent.def_base)
    if ent.model is None and not ent.solid and ent.prop("model") and \
            ent.name.startswith(MODEL_CLASSES_FROM_KEY):
        ent.model = '{ "path": model, "skin": skin, "frame": sequence }'


def emit(ent, as_base=None):
    out = []
    head = "@SolidClass" if ent.solid else "@PointClass"
    attrs = []
    if as_base:
        out.append("@BaseClass = %s" % as_base)
        out.append("[")
        emit_body(ent, out)
        out.append("]")
        return "\n".join(out)
    if ent.bases:
        attrs.append("base(%s)" % ", ".join(ent.bases))
    if ent.color:
        attrs.append("color(%s)" % ent.color)
    if ent.size and not ent.solid:
        attrs.append("size(%s, %s)" % (ent.size[0], ent.size[1]))
    if ent.model:
        attrs.append("model(%s)" % ent.model)
    out.append("%s %s = %s : %s" % (head, " ".join(attrs), ent.name,
                                     fgd_str(ent.desc or ent.name)) if attrs else
               "%s = %s : %s" % (head, ent.name, fgd_str(ent.desc or ent.name)))
    out.append("[")
    emit_body(ent, out)
    out.append("]")
    return "\n".join(out)


def emit_body(ent, out):
    for p in ent.props:
        label = fgd_str(p.label or humanize(p.key))
        desc = fgd_str(p.desc)
        if p.kind == "choices":
            default = p.default if re.match(r"^-?\d+$", p.default or "") else p.choices[0][0]
            out.append('\t%s(choices) : %s : %s : %s =' % (p.key, label, default, desc))
            out.append("\t[")
            for v, cap in p.choices:
                value = v if re.match(r"^-?\d+(\.\d+)?$", v) else fgd_str(v)
                out.append("\t\t%s : %s" % (value, fgd_str(cap)))
            out.append("\t]")
        else:
            out.append('\t%s(%s) : %s : %s : %s' % (p.key, p.kind, label,
                                                   fgd_str(p.default), desc))
    if ent.flags:
        out.append("\tspawnflags(flags) =")
        out.append("\t[")
        for bit in sorted(ent.flags):
            cap, d = ent.flags[bit]
            out.append("\t\t%d : %s : 0 : %s" % (bit, fgd_str(cap), fgd_str(d or cap)))
        out.append("\t]")
    # TrenchBroom keys inputs and outputs by name like properties, so an input
    # named like one of the entity's keys would be dropped as a duplicate
    taken = {p.key.lower() for p in ent.props}
    for which, lst in (("input", ent.inputs), ("output", ent.outputs)):
        for name, kind, desc in lst:
            if name.lower() in taken:
                continue
            taken.add(name.lower())
            out.append("\t%s %s(%s) : %s" % (which, name, kind, fgd_str(desc)))


# ---------------------------------------------------------------- hand-written

CLASS_START_RE = re.compile(r"@(PointClass|SolidClass|BaseClass)\b[^=]*=\s*([A-Za-z0-9_]+)")


def split_fgd_blocks(text):
    """Splits an FGD into (classname or None, text) chunks at class boundaries."""
    chunks, i, n = [], 0, len(text)
    while i < n:
        m = CLASS_START_RE.search(text, i)
        if not m:
            chunks.append((None, text[i:]))
            break
        if m.start() > i:
            chunks.append((None, text[i:m.start()]))
        j, depth, inq = m.end(), 0, False
        started = False
        while j < n:
            c = text[j]
            if c == '"':
                inq = not inq
            elif not inq and c == "/" and text.startswith("//", j):
                j = text.find("\n", j)
                j = n if j < 0 else j
                continue
            elif not inq and c == "[":
                depth += 1
                started = True
            elif not inq and c == "]":
                depth -= 1
                if started and depth == 0:
                    j += 1
                    break
            j += 1
        chunks.append((m.group(2), text[m.start():j]))
        i = j
    return chunks


# ---------------------------------------------------------------- driver

def build(args):
    sources = {}
    fw, st = args.framework, args.stiletto
    nuclide_dirs = lambda root: [os.path.join(root, "src", d) for d in ("gs-entbase", "shared", "server")]
    parents = {}
    if fw and os.path.isdir(os.path.join(fw, "src", "gs-entbase")):
        sources["nuclide:framework"] = scan_quaked(nuclide_dirs(fw), "Nuclide")
        parents["nuclide:framework"] = scan_parents([os.path.join(fw, "src")])
    if st and os.path.isdir(os.path.join(st, "src", "gs-entbase")):
        sources["nuclide:stiletto"] = scan_quaked(nuclide_dirs(st), "Nuclide")
        parents["nuclide:stiletto"] = scan_parents([os.path.join(st, "src")])
    games = {}
    if st:
        games["stiletto"] = os.path.join(st, "base")
    valve = args.valve or (os.path.join(fw, "valve") if fw else None)
    if valve:
        games["valve"] = valve
    if args.coop:
        games["coop"] = args.coop
    for key, gdir in games.items():
        if not gdir or not os.path.isdir(gdir):
            continue
        qc = scan_quaked([os.path.join(gdir, "src")], key)
        sources["game:" + key] = (gdir, qc)
        parents["game:" + key] = scan_parents([os.path.join(gdir, "src")])

    built = 0
    for prof in PROFILES:
        for fname, title, layers in prof["files"]:
            missing = [l for l in layers if not l.startswith("shared:") and l not in sources]
            if missing:
                print("skip %s/%s (no source for %s)" % (prof["dir"], fname, ", ".join(missing)))
                continue
            merged = {}       # classname -> EntClass (generated)
            hand = []         # (layer, [(name, text)])
            pool = {}
            lineage = {}
            for layer in layers:
                if layer.startswith("shared:"):
                    hand.append((layer, split_fgd_blocks(read(os.path.join(SHARED, layer[7:])))))
                elif layer.startswith("nuclide:"):
                    lineage.update(parents[layer])
                    for name, ent in sources[layer].items():
                        merged[name] = ent
                        pool[name] = ent
                else:
                    gdir, qc = sources[layer]
                    pool.update(qc)
                    lineage.update(parents[layer])
                    for name, ent in qc.items():
                        merged[name] = ent
                    for name, ent in defs_to_classes(parse_decls(os.path.join(gdir, "decls", "def")), pool, lineage).items():
                        merged[name] = ent
                    for name, ent in lua_classes(os.path.join(gdir, "scripts", "vscripts", "entities")).items():
                        if name not in merged:
                            merged[name] = ent
            # generated classes are finished on copies, so profiles don't share state
            gen = []
            if prof.get("simple"):
                merged = {n: e for n, e in merged.items() if not re.match(r"nc[A-Z]", n)}
            for name in sorted(merged, key=lambda n: (n != "worldspawn", n.lower())):
                ent = copy.deepcopy(merged[name])
                finish(ent, prof["scripting"])
                if name in NOTES:
                    ent.desc = (ent.desc.rstrip() + " " + NOTES[name]).strip()
                gen.append(ent)
            names = set(merged)
            out = [
                "// %s" % title,
                "// Generated by build_fgd.py from the game's QuakeC, entityDef and script",
                "// sources plus shared/*.fgd. Edit those and rebuild; edits here are lost.",
                "",
            ]
            compile_only = []
            for layer, chunks in hand:
                if layer.startswith("shared:compile-entities"):
                    for name, text in chunks:
                        if name is None or name not in names:
                            compile_only.append(text)
                    continue
                out.append("// ---- %s" % layer[7:])
                for name, text in chunks:
                    out.append(text)
            def_bases = sorted({e.def_base for e in gen if e.def_base})
            if def_bases:
                out.append("\n// ---- keys of the QuakeC classes entityDefs spawn as\n")
                for b in def_bases:
                    base = copy.deepcopy(pool[b])
                    finish(base, False)
                    out.append(emit(base, as_base="Def_" + b))
                    out.append("")
            out.append("\n// ---- entities (%d)\n" % len(gen))
            for ent in gen:
                out.append(emit(ent))
                out.append("")
            if compile_only:
                out.append("// ---- compile-entities.fgd (classes the game code doesn't define)")
                out.extend(compile_only)
            dest_dir = os.path.join(GAMES, prof["dir"])
            os.makedirs(dest_dir, exist_ok=True)
            dest = os.path.join(dest_dir, fname)
            with open(dest, "w", encoding="utf-8", newline="\n") as fh:
                fh.write("\n".join(out).rstrip() + "\n")
            print("wrote %s/%s: %d entities" % (prof["dir"], fname, len(gen)))
            built += 1
    return built


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--framework", help="Nuclide checkout with the Bulwark script hooks (src/gs-entbase)")
    ap.add_argument("--stiletto", help="Nuclide checkout that holds Stiletto Proto's base/")
    ap.add_argument("--valve", help="Rad-Therapy game dir (default: <framework>/valve)")
    ap.add_argument("--coop", help="Bulwark's games/coop")
    args = ap.parse_args()
    if not build(args):
        print("nothing built; pass at least one source checkout", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
