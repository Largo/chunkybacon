"""Split one fox panel into parts and trace each with potrace.
args: src.png out.json x0 y0 x1 y1 partspec.json
partspec: {"name": {"boxes": [[xa,ya,xb,yb],...], "fill": true|false}} in crop coords.
An ink component belongs to the first part whose box contains its centroid."""
import sys, json, numpy as np, potrace
from PIL import Image
from scipy import ndimage as ndi
src, out = sys.argv[1], sys.argv[2]
x0, y0, x1, y1 = map(int, sys.argv[3:7])
spec = json.load(open(sys.argv[7]))
K = 6
im = Image.open(src).convert("L").crop((x0, y0, x1, y1))
W, H = im.size
g = np.asarray(im, dtype=float)
ink = g < 128
lab, n = ndi.label(ink, structure=np.ones((3, 3)))
cents = ndi.center_of_mass(ink, lab, range(1, n + 1))
pxs = ndi.sum(ink, lab, range(1, n + 1))
names = list(spec)
part_of = np.zeros(n + 1, int)
for i, (cy, cx) in enumerate(cents, 1):
    for p, name in enumerate(names, 1):
        sp = spec[name]
        if not (sp.get("minpx", 0) <= pxs[i - 1] <= sp.get("maxpx", 1e9)): continue
        if any(a <= cx < c and b <= cy < d for a, b, c, d in spec[name]["boxes"]):
            part_of[i] = p; break
L = part_of[lab]                        # low-res part label per ink pixel
for p, name in enumerate(names, 1):     # letters drawn into another line: cut them out by box
    for xa, ya, xb, yb in spec[name].get("grab", []):
        sub = L[ya:yb, xa:xb]; sub[ink[ya:yb, xa:xb]] = p
# hi-res ink from the smoothly upscaled grey image
gh = np.asarray(im.resize((W * K, H * K), Image.BICUBIC), dtype=float)
inkh = gh < 128
Lh = np.kron(L, np.ones((K, K), int))
_, (iy, ix) = ndi.distance_transform_edt(Lh == 0, return_indices=True)
Lnear = Lh[iy, ix]
# body fill: non-ink regions not connected to the top row (bottoms are open at the panel edge)
free = ~ink
flab, fn = ndi.label(free)
outside = set(flab[0, :]) - {0}
for name in names:
    for xy in spec[name].get("outside", []):
        outside.add(flab[xy[1], xy[0]])
holes = free & ~np.isin(flab, list(outside))
result = {"width": W, "height": H, "parts": {}}
def trace(mask):
    bm = potrace.Bitmap(~mask)  # potracer traces the False pixels
    plist = bm.trace(turdsize=6, alphamax=1.0, opticurve=True, opttolerance=0.3)
    d = []
    f = lambda p: f"{p.x / K:.2f} {p.y / K:.2f}"
    for c in plist:
        d.append("M" + f(c.start_point))
        for s in c:
            if s.is_corner: d.append("L" + f(s.c) + "L" + f(s.end_point))
            else: d.append("C" + f(s.c1) + " " + f(s.c2) + " " + f(s.end_point))
        d.append("Z")
    return "".join(d)
for p, name in enumerate(names, 1):
    m = inkh & (Lnear == p)
    entry = {"ink": trace(m)}
    if spec[name].get("fill"):
        # holes enclosed by this part's ink, grown under the outline
        hl, hn = ndi.label(holes)
        mine = np.zeros_like(holes)
        for h in range(1, hn + 1):
            reg = hl == h
            ring = ndi.binary_dilation(reg, iterations=2) & ink
            if ring.any() and np.bincount(L[ring], minlength=len(names) + 1).argmax() == p and not (flab[hl == h] == 0).all():
                mine |= reg
        group = [p] + [names.index(m) + 1 for m in spec[name].get("with", [])]
        mine = ndi.binary_dilation(mine, iterations=1) | np.isin(L, group[1:])
        pad = np.vstack([mine, np.ones((1, W), bool)])   # the open bottom edge closes the body
        mine = ndi.binary_fill_holes(pad)[:-1] & ~(ink & (L == p))
        fh = np.kron(mine, np.ones((K, K), bool))
        fh = ndi.binary_dilation(fh, iterations=4)        # tuck ~2/3 px under the outline
        fh &= ~ndi.binary_dilation(~np.kron(mine | (ink & (L == p)), np.ones((K, K), bool)), iterations=1)
        entry["fill"] = trace(fh)
        # where the body meets the open bottom edge: outline strokes and fill span in the last row
        row = ink[-1] & (L[-1] == p)
        xs = np.flatnonzero(np.diff(np.r_[0, row.astype(int), 0]))
        entry["bottomInk"] = [[int(a), int(b)] for a, b in zip(xs[::2], xs[1::2])]
        fr = np.flatnonzero(mine[-1])
        entry["bottomFill"] = [int(fr.min()), int(fr.max()) + 1] if len(fr) else None
    ys, xs = np.nonzero(L == p)
    entry["bbox"] = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1] if len(xs) else None
    result["parts"][name] = entry
    print(name, entry["bbox"], len(entry["ink"]), len(entry.get("fill", "")))
json.dump(result, open(out, "w"))
# preview
svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W*3}" height="{H*3}"><rect width="{W}" height="{H}" fill="#EE3F24"/>']
for name, e in result["parts"].items():
    if "fill" in e: svg.append(f'<path d="{e["fill"]}" fill="#fff" fill-rule="evenodd"/>')
    svg.append(f'<path d="{e["ink"]}" fill="#111" fill-rule="evenodd"/>')
svg.append("</svg>")
open(out.replace(".json", "-preview.svg"), "w").write("".join(svg))
