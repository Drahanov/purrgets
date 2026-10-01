#!/usr/bin/env python3
"""Renders the README diagrams to PNG with headless Chrome.

Usage: python3 docs/diagrams/build.py
"""
import pathlib
import subprocess
import tempfile

HERE = pathlib.Path(__file__).parent
OUT = HERE.parent / "images"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

INK, PAPER, CARD = "#161514", "#F6F1E7", "#FFFDF8"
TANGERINE, MARIGOLD, SAND = "#EE8B3A", "#F2B441", "#DDD3B4"
MUTED = "#6B6259"


def chip(x, y, w, h, title, sub="", fill=CARD, color=INK, sub_color=MUTED):
    cx = x + w / 2
    ty = y + h / 2 + (-4 if sub else 7)
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}"/>'
    s += f'<text x="{cx}" y="{ty}" class="t" fill="{color}">{title}</text>'
    if sub:
        s += f'<text x="{cx}" y="{ty + 22}" class="s" fill="{sub_color}">{sub}</text>'
    return s


def panel(x, y, w, h, title, fill, color=INK, tag=""):
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="22" fill="{fill}"/>'
    s += f'<text x="{x + 22}" y="{y + 36}" class="h" fill="{color}">{title}</text>'
    if tag:
        s += f'<text x="{x + w - 22}" y="{y + 36}" class="tag" fill="{color}">{tag}</text>'
    return s


def file_icon(cx, y, w, h, title, sub):
    x, ry = cx - w / 2, 12
    s = (f'<path d="M{x},{y + ry} v{h - 2 * ry} a{w / 2},{ry} 0 0 0 {w},0 v{-(h - 2 * ry)}" '
         f'fill="{INK}"/>')
    s += f'<ellipse cx="{cx}" cy="{y + ry}" rx="{w / 2}" ry="{ry}" fill="#3A3633"/>'
    s += f'<text x="{cx}" y="{y + h / 2 + 10}" class="t" fill="{PAPER}">{title}</text>'
    s += f'<text x="{cx}" y="{y + h / 2 + 30}" class="s" fill="{SAND}">{sub}</text>'
    return s


def arrow(points, dashed=False, label="", lx=0, ly=0):
    d = "M" + " L".join(f"{x},{y}" for x, y in points)
    dash = ' stroke-dasharray="7 6"' if dashed else ""
    s = f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="2.5"{dash} marker-end="url(#a)"/>'
    if label:
        s += f'<text x="{lx}" y="{ly}" class="l">{label}</text>'
    return s


def page(w, h, body):
    return f"""<!doctype html><html><head><style>
@font-face {{ font-family: R; src: url("file:///System/Library/Fonts/SFNSRounded.ttf"); }}
html, body {{ margin: 0; background: {PAPER}; }}
text {{ font-family: R, ui-rounded, system-ui; text-anchor: middle; }}
.h {{ font-size: 22px; font-weight: 800; text-anchor: start; }}
.tag {{ font-size: 14px; font-weight: 700; text-anchor: end; opacity: .75; }}
.t {{ font-size: 18px; font-weight: 750; }}
.s {{ font-size: 14px; font-weight: 500; }}
.l {{ font-size: 14px; font-weight: 700; fill: {INK}; }}
.k {{ font-size: 13px; font-weight: 600; }}
.g {{ font-size: 15px; font-weight: 700; fill: {MUTED}; }}
.n {{ font-size: 15px; font-weight: 800; fill: {PAPER}; }}
.c {{ font-size: 15px; font-weight: 600; fill: {MUTED}; }}
</style></head><body>
<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
<defs><marker id="a" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="6" markerHeight="6" orient="auto">
<path d="M0,0 L10,5 L0,10 z" fill="{INK}"/></marker></defs>
{body}
</svg></body></html>"""


def comp(x, y, w, name, tech, desc, fill, color=INK, sub=MUTED, h=100):
    """C4-style component: name, [technology], one-line responsibility."""
    cx = x + w / 2
    s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="{fill}"/>'
    s += f'<text x="{cx}" y="{y + 36}" class="t" fill="{color}">{name}</text>'
    s += f'<text x="{cx}" y="{y + 58}" class="k" fill="{sub}">[{tech}]</text>'
    s += f'<text x="{cx}" y="{y + 81}" class="s" fill="{sub}">{desc}</text>'
    return s


def group(x, y, w, h, title):
    s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="20" fill="none" '
         f'stroke="{MUTED}" stroke-width="2" stroke-dasharray="8 6"/>')
    s += f'<text x="{x + 18}" y="{y + 28}" class="g" style="text-anchor:start">{title}</text>'
    return s


def lab(x, y, text, anchor="middle"):
    return f'<text x="{x}" y="{y}" class="l" style="text-anchor:{anchor}">{text}</text>'


def architecture():
    APP, WID, KT, EXT = TANGERINE, MARIGOLD, INK, SAND
    b = ""
    b += group(30, 30, 590, 180, "App process")
    b += comp(60, 80, 220, "Screens", "SwiftUI", "home, editor", APP, sub=INK)
    b += comp(380, 80, 220, "ViewModel", "Swift", "holds screen state", APP, sub=INK)
    b += comp(770, 80, 200, "WidgetKit", "iOS", "runs widgets", EXT)
    b += group(1110, 30, 260, 180, "Widget process")
    b += comp(1130, 80, 220, "Widget", "SwiftUI", "draws one tracker", WID, sub=INK)
    b += group(30, 270, 1340, 320, "Shared Kotlin module · linked into both processes")
    b += comp(580, 320, 240, "Use cases", "Kotlin", "days left, when to redraw", KT, color=PAPER, sub=SAND)
    b += comp(330, 460, 280, "TrackerRepository", "Kotlin", "loads and saves trackers", KT, color=PAPER, sub=SAND)
    b += comp(790, 460, 280, "CalendarSource", "Kotlin", "reads calendar events", KT, color=PAPER, sub=SAND)
    b += file_icon(470, 650, 220, 90, "trackers.json", "App Group file")
    b += comp(820, 650, 220, "Calendar", "EventKit", "iOS calendar", EXT, h=90)
    # app
    b += arrow([(280, 130), (376, 130)]) + lab(328, 118, "taps")
    b += arrow([(600, 130), (766, 130)], dashed=True) + lab(695, 118, "reload widgets")
    b += arrow([(970, 130), (1126, 130)]) + lab(1048, 118, "asks for frames")
    b += arrow([(490, 180), (490, 370), (576, 370)]) + lab(500, 245, "save, calculate", "start")
    b += arrow([(1240, 180), (1240, 370), (824, 370)]) + lab(1250, 245, "get frames", "start")
    b += arrow([(650, 420), (650, 440), (470, 440), (470, 456)]) + lab(560, 434, "load · save")
    b += arrow([(750, 420), (750, 440), (930, 440), (930, 456)]) + lab(840, 434, "fetch events")
    b += arrow([(470, 560), (470, 646)]) + lab(480, 615, "reads · writes", "start")
    b += arrow([(930, 560), (930, 646)]) + lab(940, 615, "reads", "start")
    # legend
    ly = 790
    for i, (fill, text) in enumerate([(APP, "App (Swift)"), (WID, "Widget (Swift)"),
                                      (KT, "Shared (Kotlin)"), (EXT, "Apple system")]):
        x = 30 + i * 200
        b += f'<rect x="{x}" y="{ly - 16}" width="22" height="22" rx="6" fill="{fill}"/>'
        b += f'<text x="{x + 32}" y="{ly}" class="c" style="text-anchor:start">{text}</text>'
    b += arrow([(830, ly - 5), (880, ly - 5)]) + f'<text x="892" y="{ly}" class="c" style="text-anchor:start">calls</text>'
    b += arrow([(960, ly - 5), (1010, ly - 5)], dashed=True) + f'<text x="1022" y="{ly}" class="c" style="text-anchor:start">signal</text>'
    b += (f'<rect x="1110" y="{ly - 18}" width="40" height="26" rx="6" fill="none" stroke="{MUTED}" '
          f'stroke-width="2" stroke-dasharray="6 4"/><text x="1162" y="{ly}" class="c" style="text-anchor:start">process / module</text>')
    return page(1400, 830, b)


def data_flow():
    APP, WID, KT, EXT = TANGERINE, MARIGOLD, INK, SAND
    cols = {"user": 170, "app": 400, "kt": 630, "json": 860, "wk": 1090, "wid": 1310}
    heads = [("user", "User", "", PAPER, INK, INK), ("app", "App", "Swift", APP, INK, INK),
             ("kt", "Shared logic", "Kotlin", KT, PAPER, SAND), ("json", "trackers.json", "App Group", KT, PAPER, SAND),
             ("wk", "WidgetKit", "iOS", EXT, INK, MUTED), ("wid", "Widget", "Swift", WID, INK, INK)]
    steps = [
        ("Add a widget", None),
        ("user", "wk", "adds widget to Home Screen", False),
        ("wk", "wid", "which trackers can I show?", False),
        ("wid", "kt", "load trackers", False),
        ("kt", "json", "read", False),
        ("user", "wk", "picks a tracker", False),
        ("note", "wk", "iOS stores tracker id for this widget"),
        ("Edit a tracker", None),
        ("user", "app", "edits and taps Save", False),
        ("app", "kt", "save tracker", False),
        ("kt", "json", "write", False),
        ("app", "wk", "reloadTimelines()", True),
        ("Widget redraws (after 5, 9, or at the planned reload time)", None),
        ("wk", "wid", "frames for tracker id", False),
        ("wid", "kt", "load tracker, plan frames", False),
        ("kt", "json", "read", False),
        ("wid", "wk", "frames + next reload time", True),
        ("note", "wk", "shows each frame at its time"),
    ]
    b, y, n = "", 150, 0
    sec = ""
    rows = []
    for st in steps:
        if st[1] is None:
            y += 22
            sec += f'<line x1="30" y1="{y + 8}" x2="1410" y2="{y + 8}" stroke="{SAND}" stroke-width="2"/>'
            sec += f'<rect x="24" y="{y - 20}" width="{len(st[0]) * 8.4 + 14}" height="28" fill="{PAPER}"/>'
            sec += f'<text x="30" y="{y}" class="g" style="text-anchor:start">{st[0]}</text>'
            y += 46
            continue
        rows.append((y, st))
        y += 56
    height = y + 70
    for key, name, tech, fill, color, sub in heads:
        cx = cols[key]
        b += f'<line x1="{cx}" y1="106" x2="{cx}" y2="{height - 70}" stroke="{MUTED}" stroke-width="1.5" stroke-dasharray="5 6"/>'
        b += f'<rect x="{cx - 100}" y="30" width="200" height="76" rx="14" fill="{fill}" stroke="{INK if fill == PAPER else fill}" stroke-width="2"/>'
        b += f'<text x="{cx}" y="{64 if tech else 75}" class="t" fill="{color}">{name}</text>'
        if tech:
            b += f'<text x="{cx}" y="{88}" class="k" fill="{sub}">[{tech}]</text>'
    b += sec
    for y, st in rows:
        if st[0] == "note":
            cx = cols[st[1]]
            b += f'<rect x="{cx - 150}" y="{y - 24}" width="300" height="38" rx="10" fill="{CARD}" stroke="{SAND}" stroke-width="2"/>'
            b += f'<text x="{cx}" y="{y + 1}" class="s" fill="{INK}">{st[2]}</text>'
            continue
        n += 1
        a, c, label, dashed = st
        x1, x2 = cols[a], cols[c]
        d = 6 if x2 > x1 else -6
        b += arrow([(x1, y), (x2 - d, y)], dashed=dashed)
        w = len(label) * 8.2 + 16
        b += f'<rect x="{(x1 + x2) / 2 - w / 2}" y="{y - 29}" width="{w}" height="26" fill="{PAPER}"/>'
        b += lab((x1 + x2) / 2, y - 10, label)
        b += f'<circle cx="52" cy="{y - 4}" r="15" fill="{INK}"/><text x="52" y="{y + 1}" class="n">{n}</text>'
    ly = height - 25
    b += arrow([(30, ly - 5), (80, ly - 5)]) + f'<text x="92" y="{ly}" class="c" style="text-anchor:start">call</text>'
    b += arrow([(170, ly - 5), (220, ly - 5)], dashed=True) + f'<text x="232" y="{ly}" class="c" style="text-anchor:start">signal / reply</text>'
    return page(1440, height, b), height


def render(name, html, w, h):
    with tempfile.NamedTemporaryFile("w", suffix=".html", delete=False) as f:
        f.write(html)
    OUT.mkdir(parents=True, exist_ok=True)
    subprocess.run([CHROME, "--headless=new", "--allow-file-access-from-files", "--hide-scrollbars",
                    f"--window-size={w},{h}", "--force-device-scale-factor=2",
                    f"--screenshot={OUT / name}", f"file://{f.name}"],
                   check=True, capture_output=True)
    print(OUT / name)


render("architecture.png", architecture(), 1400, 830)
html, h = data_flow()
render("data-flow.png", html, 1440, h)
