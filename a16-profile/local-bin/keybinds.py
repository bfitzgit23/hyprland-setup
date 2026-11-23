#!/usr/bin/env python3
"""Keybind browser for the Hyprland config.

Hyprland 0.57 binds live in Lua (hl.bind(mainMod .. " + Q", hl.dsp...)), so
`hyprctl binds` is not the source of truth here and carries no descriptions.
This reads ~/.config/hypr/hyprland.lua directly, pairs every bind with a
human description (a trailing `-- comment` wins, otherwise the dispatcher is
translated), and shows the result in rofi.

  keybinds.py search   compact, search-as-you-type list
  keybinds.py sheet    full cheat sheet, grouped by area
  keybinds.py dump     JSON, for other tools

Selecting a bind in `search` copies its chord to the clipboard, so a hint like
"press it" can be pasted somewhere.
"""

import json
import os
import re
import shutil
import subprocess
import sys

CONFIG = os.path.expanduser("~/.config/hypr/hyprland.lua")

# Areas, in display order, with the rules that put a bind in one.
SECTIONS = [
    ("Launch & System", ("kitty", "rofi", "portage", "power-menu", "gpu-switch",
                         "loginctl lock", "dsp.exit", "wallpaper", "keybinds")),
    ("Screenshots", ("screenshot",)),
    ("Windows & Workspaces", ("window", "workspace", "focus", "special")),
    ("Mouse", ("mouse:", "drag", "resize")),
    ("Media & Brightness", ("xf86", "wpctl", "brightnessctl", "mic-toggle")),
]


def _scan_parens(text):
    """Net (minus) ) depth, ignoring parentheses inside Lua string literals."""
    depth = 0
    quote = None
    i = 0
    while i < len(text):
        ch = text[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        i += 1
    return depth


def _split_args(inner):
    """Split a Lua argument list on top-level commas."""
    args, buf = [], ""
    depth = 0
    quote = None
    i = 0
    while i < len(inner):
        ch = inner[i]
        if quote:
            buf += ch
            if ch == "\\":
                buf += inner[i + 1] if i + 1 < len(inner) else ""
                i += 2
                continue
            if ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
            buf += ch
        elif ch in "({[":
            depth += 1
            buf += ch
        elif ch in ")}]":
            depth -= 1
            buf += ch
        elif ch == "," and depth == 0:
            args.append(buf.strip())
            buf = ""
        else:
            buf += ch
        i += 1
    if buf.strip():
        args.append(buf.strip())
    return args


def parse_binds(path=CONFIG):
    """Return [{chord, action, note, section}] in config order."""
    with open(path, encoding="utf-8") as fh:
        lines = fh.readlines()

    binds = []
    i = 0
    loop_max = 0            # >0 while inside `for i = 1, 9 do`
    while i < len(lines):
        raw = lines[i]
        stripped = raw.strip()

        loop = re.match(r"for\s+(\w+)\s*=\s*(\d+)\s*,\s*(\d+)\s+do", stripped)
        if loop:
            loop_max = int(loop.group(3))
            i += 1
            continue
        if stripped.startswith("end") and loop_max:
            loop_max = 0
            i += 1
            continue

        if not stripped.startswith("hl.bind("):
            i += 1
            continue

        # Join wrapped lines until the call's parentheses balance.
        chunk = raw.rstrip("\n")
        while _scan_parens(chunk) > 0 and i + 1 < len(lines):
            i += 1
            chunk += "\n" + lines[i].rstrip("\n")

        note = ""
        m = re.search(r"--\s*(.+)$", chunk)
        if m:
            note = m.group(1).strip()
            chunk = chunk[: m.start()]

        inner = chunk[chunk.index("(") + 1 : chunk.rindex(")")]
        args = _split_args(inner)
        if len(args) < 2:
            i += 1
            continue

        chord_expr, disp = args[0], args[1]
        for n in ([None] if not loop_max else list(range(1, loop_max + 1))):
            binds.append(
                {
                    "chord": render_chord(chord_expr, n),
                    "action": describe(disp, note, n),
                    "note": note,
                    "section": section_of(disp, note),
                }
            )
        i += 1
    return binds


def render_chord(expr, loop_value=None):
    parts = re.findall(r'"([^"]*)"', expr)
    chord = "".join(parts) if parts else expr
    # mainMod itself sits outside the quoted fragments (mainMod .. " + Q"), so
    # it has to be substituted on the expression, not on the result.
    if "mainMod" in expr:
        chord = "SUPER" + chord
    if loop_value is not None and re.search(r"\.\.\s*\w+\s*$", expr):
        chord += str(loop_value)
    chord = re.sub(r"\s*\+\s*", " + ", chord).strip()
    return re.sub(r"\s{2,}", " ", chord)


def _cmd_text(cmd):
    """Human phrase for a shell command."""
    base = os.path.basename(cmd.split()[0]) if cmd.split() else cmd
    pretty = {
        "kitty": "Open terminal (kitty)",
        "rofi": "App launcher (rofi)",
        "nmtui": "Network settings (nmtui)",
        "loginctl": "Lock the session",
        "gpu-switch.sh": "Switch GPU profile",
        "power-menu.sh": "Power menu",
        "mic-toggle.sh": "Mute/unmute microphone",
        "portage-update.sh": "Update the system (portage)",
        "keybinds.py": "This keybind browser",
        "wallpaper-picker.sh": "Choose wallpaper",
        "wallpaper-rotate.sh": "Restart wallpaper rotation",
        "screenshot.sh": "Take a screenshot",
        "brightnessctl": "Brightness",
        "wpctl": "Audio",
    }
    # Scripts are usually reached through a launcher (kitty -e portage-update.sh),
    # so the wrapped script has to win over the first word. Longest name first,
    # otherwise "kitty" swallows the portage updater's whole command.
    for name in sorted(pretty, key=len, reverse=True):
        if name in cmd:
            return pretty[name]
    return "Run " + base


def describe(disp, note, loop_value=None):
    arg = " ".join(re.findall(r'"([^"]*)"', disp))
    low = disp.lower()

    if "exec_cmd" in low:
        if "screenshot.sh" in arg:
            area, mode = (arg.split()[1:2] + ["region"])[0], arg.split()[-1]
            where = {"region": "region", "output": "whole screen",
                     "full": "all screens"}.get(area, area)
            return f"Screenshot: {where} → {mode}"
        if "keybinds.py" in arg:
            return "Keybind list (all binds)" if "sheet" in arg else "Search keybinds"
        if "wpctl" in arg:
            if "set-mute" in arg:
                return "Mute/unmute speakers"
            return "Volume up" if "5%+" in arg else "Volume down"
        if "brightnessctl" in arg:
            return "Brightness up" if "5%+" in arg else "Brightness down"
        return _cmd_text(arg)

    if "window.close" in low:
        return "Close the focused window"
    if "dsp.exit" in low:
        return "Exit Hyprland"
    if "window.float" in low:
        return "Toggle floating"
    if "window.fullscreen" in low:
        return "Maximize (bar stays visible)" if "mode = 1" in disp else "Toggle fullscreen"
    if "window.drag" in low:
        return "Move window (drag with mouse)"
    if "window.resize" in low:
        return "Resize window (drag with mouse)"
    if "toggle_special" in low:
        return "Show/restore minimized windows"
    if "window.move" in low and "special:" in low:
        return "Minimize to a hidden workspace"
    if "window.move" in low:
        target = re.search(r"workspace\s*=\s*\"?([\w:]+)\"?", disp)
        if target and loop_value is not None:
            return f"Move window to workspace {loop_value}"
        return "Move window"
    if "window.swap" in low:
        d = re.search(r"direction\s*=\s*\"(\w+)\"", disp)
        return f"Swap window {d.group(1)}" if d else "Swap window"
    if "focus" in low and "direction" in low:
        d = re.search(r"direction\s*=\s*\"(\w+)\"", disp)
        return f"Focus window {d.group(1)}" if d else "Focus window"
    if "workspace" in low:
        return f"Switch to workspace {loop_value}" if loop_value is not None else "Switch workspace"

    if note:
        return note
    return re.sub(r"hl\.dsp\.|\(\s*\)|[{}]", "", disp).strip()


def section_of(disp, note):
    hay = (disp + " " + note).lower()
    for name, keys in SECTIONS:
        if any(k in hay for k in keys):
            return name
    return "Other"


def row(bind, width=24):
    return f"{bind['chord']:<{width}}{bind['action']}"


def rofi(rows, prompt, lines):
    cmd = ["rofi", "-dmenu", "-i", "-p", prompt, "-no-custom",
           "-theme-str",
           f"window {{ width: 760px; }} listview {{ lines: {lines}; }}"]
    try:
        out = subprocess.run(cmd, input="\n".join(rows) + "\n",
                             capture_output=True, text=True).stdout.strip()
    except FileNotFoundError:
        sys.exit("rofi is not installed")
    return out


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "search"
    binds = parse_binds()

    if mode == "dump":
        print(json.dumps(binds, indent=2))
        return

    width = max((len(b["chord"]) for b in binds), default=10) + 4

    if mode == "sheet":
        rows = [f"{len(binds)} keybinds - type to filter, Esc to close"]
        for name, _ in SECTIONS + [("Other", ())]:
            group = [b for b in binds if b["section"] == name]
            if not group:
                continue
            label = f"-- {name.upper()} ({len(group)}) "
            rows.append(label + "-" * max(0, 52 - len(label)))
            rows.extend(row(b, width) for b in group)
        rofi(rows, "Keybinds", min(len(rows), 34))
        return

    # search: one row per bind, no headers, so every hit is actionable.
    by_row = {row(b, width): b for b in binds}
    choice = rofi(sorted(by_row), "Search keybinds", 18)
    if not choice:
        return
    bind = by_row.get(choice)
    if not bind:
        return
    text = f"{bind['chord']}\t{bind['action']}"
    if shutil.which("wl-copy"):
        subprocess.run(["wl-copy", bind["chord"]], check=False)
        subprocess.run(["notify-send", "Keybind",
                        f"{bind['chord']} — {bind['action']}\n(chord copied)"],
                       check=False)
    else:
        subprocess.run(["notify-send", "Keybind", text], check=False)


if __name__ == "__main__":
    main()
