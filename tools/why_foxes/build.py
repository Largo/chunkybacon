"""Build fox SVGs from the traced parts of panel 4c.
args: parts.json layers_dir repo_dir"""
import sys, json, math, os
P = json.load(open(sys.argv[1]))["parts"]
LAY, REPO = sys.argv[2], sys.argv[3]
os.makedirs(LAY, exist_ok=True); os.makedirs(REPO, exist_ok=True)
VB = "0 -18 264 242"
INK = "#1a1612"
CREDIT = ("Cartoon foxes by why the lucky stiff, from why's (poignant) guide to Ruby, chapter 3 "
          "(the.foxes-4c.png). CC BY-SA 2.5, https://creativecommons.org/licenses/by-sa/2.5/ . "
          "Traced to SVG, split into parts and animated for Chunky Bacon; balloons redrawn.")

def wobble_balloon(cx, cy, rx, ry, tip, gap_deg, seed):
    ang_tip = math.degrees(math.atan2(tip[1] - cy, tip[0] - cx))
    a0, a1 = ang_tip - gap_deg / 2, ang_tip + gap_deg / 2
    n = 26
    pts = []
    for i in range(n + 1):
        a = math.radians(a1 + (360 - gap_deg) * i / n)
        j = 1 + 0.022 * math.sin(i * 2.7 + seed) + 0.012 * math.sin(i * 5.3 + 2 * seed)
        pts.append((cx + rx * j * math.cos(a), cy + ry * j * math.sin(a)))
    f = lambda p: f"{p[0]:.2f} {p[1]:.2f}"
    d = ["M" + f(pts[0])]
    for i in range(len(pts) - 1):           # Catmull-Rom -> cubic Bezier
        p0 = pts[max(i - 1, 0)]; p1 = pts[i]; p2 = pts[i + 1]; p3 = pts[min(i + 2, len(pts) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d.append("C" + f(c1) + " " + f(c2) + " " + f(p2))
    d.append("L" + f(tip) + "Z")
    return "".join(d)

BIG = wobble_balloon(126, 22, 99, 33, (98, 86), 15, 1.0)
SMALL = wobble_balloon(187, 101, 70, 43, (197, 156), 17, 2.3)

def balloon(d, text):
    return (f'<path d="{d}" fill="#fff" stroke="{INK}" stroke-width="2.3" stroke-linejoin="round"/>'
            f'<path d="{text}" fill="{INK}"/>')
def fox(name):
    e = P[name]; ext = ""
    if e.get("bottomFill"):              # continue the body below the old panel edge (seen when hopping)
        a, b = e["bottomFill"]
        ext = f'<rect x="{a}" y="223" width="{b - a}" height="40" fill="#fff"/>'
        ext += "".join(f'<rect x="{x0}" y="223" width="{x1 - x0}" height="40" fill="{INK}"/>' for x0, x1 in e["bottomInk"])
    return f'{ext}<path d="{e["fill"]}" fill="#fff"/><path d="{e["ink"]}" fill="{INK}"/>'
def mouth(name):
    return f'<path d="{P[name]["ink"]}" fill="{INK}"/>'

LAYERS = {
    "fox-tall": fox("tall"), "mouth-tall": mouth("tallMouth"),
    "fox-small": fox("small"), "mouth-small": mouth("smallMouth"),
    "balloon-big": balloon(BIG, P["textBig"]["ink"]),
    "balloon-small": balloon(SMALL, P["textSmall"]["ink"]),
}
def svg(vb, body, extra=""):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}">'
            f'<desc>{CREDIT}</desc>{extra}{body}</svg>\n')
VBL = "0 -18 264 262"                    # layers reach 20 units below the frame, to hide behind an edge
for k, body in LAYERS.items():
    open(f"{LAY}/{k}.svg", "w").write(svg(VBL, body))

# solo foxes, cropped (bottoms stay open: they stand on the bottom edge)
open(f"{REPO}/fox-tall.svg", "w").write(svg("12 87 104 137", fox("tall") + mouth("tallMouth")))
open(f"{REPO}/fox-head.svg", "w").write(svg("14 84 100 100", fox("tall") + mouth("tallMouth")))
open(f"{REPO}/fox-small.svg", "w").write(svg("160 138 104 86", fox("small") + mouth("smallMouth")))

# animated scene
CSS = """<style>
g{transform-box:view-box}
.tall{transform-origin:62px 224px;animation:tall 4.8s ease-in-out infinite}
.small{transform-origin:215px 224px;animation:small 4.8s ease-in-out infinite}
.mt{transform-origin:52px 141px;animation:mt 4.8s linear infinite}
.ms{transform-origin:231px 196px;animation:ms 4.8s linear infinite}
.bb{transform-origin:98px 86px;animation:bb 4.8s cubic-bezier(.3,1.4,.5,1) infinite}
.bs{transform-origin:197px 156px;animation:bs 4.8s cubic-bezier(.3,1.4,.5,1) infinite}
@keyframes tall{0%,6%{transform:translateY(0) rotate(0)}10%{transform:translateY(-7px) rotate(-2.5deg) scaleY(1.04)}16%{transform:translateY(0) rotate(0) scaleY(.97)}22%{transform:translateY(-5px) rotate(1.5deg)}30%,100%{transform:translateY(0) rotate(0)}}
@keyframes small{0%,40%{transform:translateY(0)}45%{transform:translateY(-12px) scaleY(1.05)}51%{transform:translateY(0) scaleY(.95)}56%{transform:translateY(-6px)}63%,100%{transform:translateY(0)}}
@keyframes mt{0%,5%{transform:scaleY(.22)}9%{transform:scaleY(1)}14%{transform:scaleY(.55)}19%{transform:scaleY(1)}26%{transform:scaleY(.7)}32%,100%{transform:scaleY(.22)}}
@keyframes ms{0%,41%{transform:scaleY(.25)}45%{transform:scaleY(1)}50%{transform:scaleY(.6)}55%{transform:scaleY(1)}61%{transform:scaleY(.7)}67%,100%{transform:scaleY(.25)}}
@keyframes bb{0%,6%{transform:scale(0);opacity:0}12%{transform:scale(1);opacity:1}86%{transform:scale(1);opacity:1}92%,100%{transform:scale(.6);opacity:0}}
@keyframes bs{0%,41%{transform:scale(0);opacity:0}47%{transform:scale(1);opacity:1}88%{transform:scale(1);opacity:1}94%,100%{transform:scale(.6);opacity:0}}
@media (prefers-reduced-motion:reduce){.tall,.small,.mt,.ms,.bb,.bs{animation:none}}
</style>"""
scene = (f'<g class="tall">{fox("tall")}<g class="mt">{mouth("tallMouth")}</g></g>'
         f'<g class="small">{fox("small")}<g class="ms">{mouth("smallMouth")}</g></g>'
         f'<g class="bb">{LAYERS["balloon-big"]}</g><g class="bs">{LAYERS["balloon-small"]}</g>')
open(f"{REPO}/chunky-bacon.svg", "w").write(svg(VB, scene, CSS))
static = "".join(LAYERS[k] for k in ["fox-tall", "mouth-tall", "fox-small", "mouth-small", "balloon-big", "balloon-small"])
open(f"{LAY}/scene-static.svg", "w").write(svg(VB, static))
for fn in sorted(os.listdir(REPO)): print(fn, os.path.getsize(f"{REPO}/{fn}"))
