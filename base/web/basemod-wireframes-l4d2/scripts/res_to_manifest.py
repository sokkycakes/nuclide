#!/usr/bin/env python3
"""Offline: L4D2 .res -> JSON manifests (control names, commands, layout hints)."""

import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(SCRIPT_DIR, ".."))
RES_DIR = os.path.join(ROOT, "res")
OUT_DIR = os.path.join(ROOT, "js", "manifests")

VIEW_MAP = {
    "mainmenu.res": "view-mainmenu",
    "gamesettings_coopcreate.res": "view-gamesettings",
    "gamelobby.res": "view-gamelobby",
    "loadingprogress.res": "view-loading",
    "ingamemainmenu.res": "view-ingame-menu",
    "voteoptions.res": "view-vote",
    "ingamechapterselect.res": "view-chapter-select",
    "ingamedifficultyselect.res": "view-difficulty-select",
    "genericconfirmation.res": "view-confirm",
    "campaignflyout.res": "flyout-campaign",
    "optionsflyout.res": "flyout-options",
}


def strip_res(text: str) -> str:
    text = text.replace("\r\n", "\n")
    text = re.sub(r"//[^\n]*", "", text)
    text = re.sub(r"\[\$[^\]]+\]", "", text)
    return text


def tokenize(text: str):
    tokens = []
    i = 0
    while i < len(text):
        c = text[i]
        if c in " \t\n":
            i += 1
            continue
        if c == "{":
            tokens.append("{")
            i += 1
            continue
        if c == "}":
            tokens.append("}")
            i += 1
            continue
        if c == '"':
            j = i + 1
            s = []
            while j < len(text):
                if text[j] == "\\" and j + 1 < len(text):
                    s.append(text[j + 1])
                    j += 2
                    continue
                if text[j] == '"':
                    break
                s.append(text[j])
                j += 1
            tokens.append("".join(s))
            i = j + 1
            continue
        i += 1
    return tokens


def parse_keyvalues(text: str) -> dict:
    tokens = tokenize(strip_res(text))
    pos = 0

    def peek():
        return tokens[pos] if pos < len(tokens) else None

    def consume():
        nonlocal pos
        t = tokens[pos]
        pos += 1
        return t

    def parse_block():
        consume()  # {
        obj = {}
        while peek() and peek() != "}":
            key = consume()
            if peek() == "{":
                obj[key] = parse_block()
            else:
                obj[key] = consume()
        if peek() == "}":
            consume()
        return obj

    if peek() and isinstance(peek(), str):
        consume()  # root filename
    return parse_block()


def parse_dim(value, parent, fallback=None):
    if value is None or value == "":
        return fallback
    s = str(value).strip()
    if s.startswith("f"):
        n = int(s[1:]) if s[1:].isdigit() else 0
        return max(0, parent - n)
    try:
        return int(s)
    except ValueError:
        return fallback


def extract_modes(block: dict) -> list:
    modes = []
    for key, val in block.items():
        if key == "mode" and isinstance(val, dict):
            modes.append({
                "id": val.get("id", ""),
                "label": val.get("label", ""),
                "command": val.get("command", ""),
            })
        elif key.startswith("mode") and isinstance(val, dict):
            modes.append({
                "id": val.get("id", ""),
                "label": val.get("label", ""),
                "command": val.get("command", ""),
            })
    return modes


def control_entry(name, block, parent_w=640, parent_h=480):
    if not isinstance(block, dict):
        return None
    if "ControlName" not in block and "fieldName" not in block and "xpos" not in block:
        return None

    field = block.get("fieldName", name)
    entry = {
        "id": field,
        "name": name,
        "controlName": block.get("ControlName", ""),
        "command": block.get("command", ""),
        "labelText": block.get("labelText", ""),
        "visible": block.get("visible", "1") != "0",
        "xpos": parse_dim(block.get("xpos"), parent_w, 0),
        "ypos": parse_dim(block.get("ypos"), parent_h, 0),
        "wide": parse_dim(block.get("wide"), parent_w, None),
        "tall": parse_dim(block.get("tall"), parent_h, None),
    }

    if entry["controlName"] == "GameModes":
        entry["modes"] = extract_modes(block)

    if entry["controlName"] == "FlyoutMenu":
        entry["resourceFile"] = block.get("ResourceFile", "")

    return entry


def build_manifest(filename: str, parsed: dict) -> dict:
    controls = []
    frame = None
    parent_w, parent_h = 640, 480

    for name, block in parsed.items():
        if not isinstance(block, dict):
            continue
        if block.get("ControlName") == "Frame" and frame is None:
            frame = block.get("fieldName", name)
            parent_w = parse_dim(block.get("wide"), 640, 640)
            parent_h = parse_dim(block.get("tall"), 480, 480)
            controls.append(control_entry(name, block, 640, 480))
            continue
        c = control_entry(name, block, parent_w, parent_h)
        if c:
            controls.append(c)

    return {
        "source": f"resource/ui/l4d360ui/{filename}",
        "viewId": VIEW_MAP.get(filename, ""),
        "frame": frame,
        "viewport": {"wide": parent_w, "tall": parent_h},
        "controls": controls,
    }


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    if not os.path.isdir(RES_DIR):
        print("missing res/", file=sys.stderr)
        sys.exit(1)

    for fname in sorted(os.listdir(RES_DIR)):
        if not fname.endswith(".res"):
            continue
        path = os.path.join(RES_DIR, fname)
        with open(path, encoding="utf-8", errors="replace") as f:
            parsed = parse_keyvalues(f.read())
        manifest = build_manifest(fname, parsed)
        out = os.path.join(OUT_DIR, fname.replace(".res", ".json"))
        with open(out, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
        print("wrote", os.path.relpath(out, ROOT))

    # Combined index for runtime
    index = {}
    for fname in os.listdir(OUT_DIR):
        if not fname.endswith(".json") or fname == "index.json":
            continue
        key = fname.replace(".json", ".res")
        with open(os.path.join(OUT_DIR, fname), encoding="utf-8") as f:
            index[key] = json.load(f)
    with open(os.path.join(OUT_DIR, "index.json"), "w", encoding="utf-8") as f:
        json.dump(index, f, indent=2)
    print("wrote js/manifests/index.json")


if __name__ == "__main__":
    main()
