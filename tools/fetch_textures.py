#!/usr/bin/env python3
"""Download every texture named in assets/textures.json and normalise it for Godot.

Both sources are CC0, so nothing here needs an account, an API key or attribution.
Each slot ends up as assets/textures/<slot>/{albedo,normal,orm}.jpg, where `orm`
packs ambient occlusion, roughness and metallic into R, G and B - exactly the
layout Godot's ORMMaterial3D expects. Poly Haven already ships that packing as
its `arm` map; ambientCG ships the channels separately, so we pack them here.
A slot with `"src": "generated"` is built here from a CC0 scan (`GENERATED`), for a
surface no CC0 library has. Each slot also gets `meta.json` (the roughness and
metallic means, for `Mats.finish`) and `source.json` (what it was fetched from, so
pointing a slot at another scan re-fetches it).

    python3 tools/fetch_textures.py            # fetch anything missing or changed
    python3 tools/fetch_textures.py --force    # re-fetch everything
"""

import io
import json
import shutil
import subprocess
import pathlib
import sys
import urllib.request
import zipfile

from PIL import Image, ImageStat

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "textures"
UA = {"User-Agent": "declutter-manor-texture-fetch/1.0"}

# ambientCG map name -> the ORM channel it belongs in, and the value to assume
# when a material simply does not ship that map (most dielectrics have no
# metalness map at all, and a missing AO map means "unoccluded").
ACG_ORM = [("AmbientOcclusion", 255), ("Roughness", 128), ("Metalness", 0)]


def get(url: str) -> bytes:
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=180) as r:
        return r.read()


def save_jpg(img: Image.Image, path: pathlib.Path, quality: int = 92) -> None:
    img.convert("RGB").save(path, "JPEG", quality=quality, optimize=True)


def fetch_polyhaven(slot: str, spec: dict, dest: pathlib.Path) -> None:
    files = json.loads(get(f"https://api.polyhaven.com/files/{spec['id']}"))
    res = spec["res"]
    # `arm` is Poly Haven's AO/Rough/Metal pack; a few older assets lack it, in
    # which case we build the same thing out of the separate maps.
    # a few assets (multi-colourway ones) name their base colour map something
    # other than "Diffuse", so the manifest can override the key.
    wanted = {"albedo": spec.get("diffuse_key", "Diffuse"), "normal": "nor_gl", "orm": "arm"}
    for out_name, key in wanted.items():
        entry = files.get(key, {}).get(res, {}).get("jpg")
        if entry:
            (dest / f"{out_name}.jpg").write_bytes(get(entry["url"]))
            continue
        if out_name != "orm":
            raise RuntimeError(f"{slot}: no {key} at {res}")
        chans = []
        for src_key, default in (("AO", 255), ("Rough", 128), ("Metal", 0)):
            e = files.get(src_key, {}).get(res, {}).get("jpg")
            chans.append(Image.open(io.BytesIO(get(e["url"]))).convert("L") if e else default)
        size = next((c.size for c in chans if not isinstance(c, int)), (1024, 1024))
        chans = [Image.new("L", size, c) if isinstance(c, int) else c.resize(size) for c in chans]
        save_jpg(Image.merge("RGB", chans), dest / "orm.jpg")


def fetch_ambientcg(slot: str, spec: dict, dest: pathlib.Path) -> None:
    url = f"https://ambientcg.com/get?file={spec['id']}_{spec['res']}-JPG.zip"
    zf = zipfile.ZipFile(io.BytesIO(get(url)))
    names = zf.namelist()

    def find(suffix: str):
        for n in names:
            if n.lower().endswith(f"_{suffix.lower()}.jpg"):
                return Image.open(io.BytesIO(zf.read(n)))
        return None

    colour = find("Color")
    if colour is None:
        raise RuntimeError(f"{slot}: no Color map in {url}")
    save_jpg(colour, dest / "albedo.jpg")

    normal = find("NormalGL") or find("Normal")
    if normal is None:
        raise RuntimeError(f"{slot}: no normal map in {url}")
    save_jpg(normal, dest / "normal.jpg")

    size = colour.size
    chans = []
    for suffix, default in ACG_ORM:
        img = find(suffix)
        chans.append(img.convert("L").resize(size) if img else Image.new("L", size, default))
    save_jpg(Image.merge("RGB", chans), dest / "orm.jpg")


def acg_maps(asset_id: str, res: str) -> dict:
    """The Color, NormalGL, Roughness and AmbientOcclusion maps of an ambientCG asset, as images."""
    zf = zipfile.ZipFile(io.BytesIO(get(f"https://ambientcg.com/get?file={asset_id}_{res}-JPG.zip")))
    maps = {}
    for n in zf.namelist():
        for key in ("Color", "NormalGL", "Roughness", "AmbientOcclusion", "Displacement"):
            if n.lower().endswith(f"_{key.lower()}.jpg"):
                maps[key] = Image.open(io.BytesIO(zf.read(n))).convert("RGB" if key in ("Color", "NormalGL") else "L")
    return maps


def build_shingles(slot: str, spec: dict, dest: pathlib.Path) -> None:
    """Architectural (laminated) asphalt shingles, laid out from a scan of asphalt granules.

    Neither ambientCG nor Poly Haven has an asphalt shingle, and it is the roof of three American
    houses in four. A shingle's weathering surface IS asphalt with mineral granules, so the base
    scan supplies the surface and this lays it out as a roof: `courses` rows per tile, each a run
    of tabs of random width over the base layer, the darker laminate band along every butt edge,
    tab-to-tab shade variation, and a height field that steps at each butt so the normal map
    casts the course shadow. The scan is shrunk 1:10 so road aggregate reads as roof granules.
    Rows run along +u and the butt edges face +v, which is down-slope for a ridge along X under
    world triplanar. Fixed seed, so a re-fetch reproduces the same roof.
    """
    import random
    from PIL import ImageChops, ImageDraw, ImageFilter
    maps = acg_maps(spec["base"], spec.get("base_res", "2K"))
    n = 2048
    courses = int(spec.get("courses", 7))
    ch = n / courses
    rng = random.Random(1907)

    # granules: the scan at a quarter size, tiled 4x4, contrast stretched (roof granules are a
    # salt-and-pepper mix, road aggregate is flatter) and levelled to a neutral mid charcoal - the
    # plan's tint picks the colourway
    from PIL import ImageOps
    q = n // 4
    small = ImageOps.autocontrast(maps["Color"].convert("L").resize((q, q), Image.LANCZOS), cutoff=1)
    small = small.point(lambda v, k=120.0 / max(ImageStat.Stat(small).mean[0], 1.0): min(255, int(v * k)))
    gran = Image.new("L", (n, n))
    for y in range(4):
        for x in range(4):
            gran.paste(small, (x * q, y * q))

    # The base layer is what shows in the gaps between the top layer's tabs: the dark "shadow
    # line" laminated shingles are sold on. The tabs cover the rest of the exposure, butt to the
    # course above, each a slightly different blend of granules.
    shade = Image.new("L", (n, n), 118)   # 200 = unshaded granules
    tabs = Image.new("L", (n, n), 0)      # top-layer thickness for the height field
    ds, dt = ImageDraw.Draw(shade), ImageDraw.Draw(tabs)
    for c in range(courses):
        top, butt = c * ch, (c + 1) * ch
        x0 = rng.uniform(0, n)
        x = x0
        while x < x0 + n:
            w = rng.uniform(0.12, 0.30) * n                  # 10-26 cm of the 0.85 m tile
            gap = rng.uniform(0.018, 0.075) * n              # 1.5-6 cm of base layer
            tone = 200 * rng.uniform(0.86, 1.12)
            for off in (0, -n):                              # wrap: the tile stays seamless
                a, b = x + off, x + w - gap + off
                # a faint gradient down each tab: the granule blend is never flat
                steps = 6
                for k in range(steps):
                    y0 = top + (butt - top) * k / steps
                    y1 = top + (butt - top) * (k + 1) / steps
                    ds.rectangle([a, y0, b, y1], fill=int(min(255, tone * (0.96 + 0.06 * k / steps))))
                dt.rectangle([a, top, b, butt], fill=50)
            x += w
        # the butt edge itself catches no sky
        ds.rectangle([0, butt - ch * 0.035, n, butt], fill=70)

    # each course rises toward its butt (it lies tilted over the one below), tabs add thickness
    ramp = Image.new("L", (1, n))
    for y in range(n):
        ramp.putpixel((0, y), int(20 + 140 * ((y % ch) / ch)))
    height = ImageChops.add(ramp.resize((n, n)), tabs)
    height = ImageChops.add(height.point(lambda v: v * 0.85), gran.point(lambda v: v * 0.10))
    height = height.filter(ImageFilter.GaussianBlur(1.2))
    shade = shade.filter(ImageFilter.GaussianBlur(0.8))

    albedo = ImageChops.multiply(gran, shade).point(lambda v: min(255, int(v * 255 / 200)))
    save_jpg(Image.merge("RGB", [albedo] * 3), dest / "albedo.jpg")
    save_jpg(height_to_normal(height, float(spec.get("relief", 6.0))), dest / "normal.jpg")
    # occlusion in the step under each butt; granule roofs are dull (roughness ~0.9)
    ao = height.filter(ImageFilter.GaussianBlur(5)).point(lambda v: 255 - max(0, 110 - v))
    save_jpg(Image.merge("RGB", [ao, Image.new("L", (n, n), 230), Image.new("L", (n, n), 0)]),
             dest / "orm.jpg")


def height_to_normal(h: "Image.Image", strength: float) -> "Image.Image":
    """OpenGL-convention (+Y up) tangent-space normal map from a height field, wrapping at the
    edges so the tile stays seamless."""
    n_w, n_h = h.size
    px = h.tobytes()
    out = bytearray(n_w * n_h * 3)
    for y in range(n_h):
        up = ((y - 1) % n_h) * n_w
        dn = ((y + 1) % n_h) * n_w
        row = y * n_w
        for x in range(n_w):
            l = px[row + (x - 1) % n_w]
            r = px[row + (x + 1) % n_w]
            u = px[up + x]
            d = px[dn + x]
            dx = (r - l) / 255.0 * strength
            dy = (u - d) / 255.0 * strength   # image y runs down; GL normal +Y is up the image
            inv = 1.0 / (dx * dx + dy * dy + 1.0) ** 0.5
            o = (row + x) * 3
            out[o] = int((-dx * inv * 0.5 + 0.5) * 255)
            out[o + 1] = int((-dy * inv * 0.5 + 0.5) * 255)
            out[o + 2] = int((inv * 0.5 + 0.5) * 255)
    return Image.frombytes("RGB", (n_w, n_h), bytes(out))


GENERATED = {"shingles": build_shingles}


# Godot only turns on mipmaps (and normal-map handling) when a texture is assigned to
# a material *in the editor* - its detect_3d pass. These materials are built at runtime,
# so that never fires and every texture imports unmipmapped, which shows up as severe
# moire shimmer on anything viewed at an angle. We therefore own the import settings.
#
# compress/mode=2 is VRAM Compressed (BC7 with high_quality). Measured on the Phase 1 garage:
# lossless import cost 4.4 s of texture load against a 0.1 s geometry build, and produced a
# 206 MB PCK. VRAM compression is not an optimisation here, it is the only way the 4 s cold
# start in docs/PACING.md is reachable - a lossless texture is decoded on the CPU at load and
# then uploaded, while a BC7 one is handed to the GPU as it sits on disk.
VRAM = {"compress/mode": "2", "compress/high_quality": "true"}
IMPORT_PARAMS = {
    "albedo": {"mipmaps/generate": "true", "detect_3d/compress_to": "0", **VRAM},
    "normal": {"mipmaps/generate": "true", "compress/normal_map": "1",
               "detect_3d/compress_to": "0", **VRAM},
    "orm": {"mipmaps/generate": "true", "detect_3d/compress_to": "0", **VRAM},
}


def patch_imports() -> int:
    """Rewrite the [params] of each generated .import file. Returns how many changed."""
    changed = 0
    for imp in sorted(OUT.glob("*/*.jpg.import")):
        want = IMPORT_PARAMS.get(imp.name.split(".")[0])
        if not want:
            continue
        lines = imp.read_text().splitlines()
        seen = set()
        out = []
        dirty = False
        for line in lines:
            key = line.split("=", 1)[0]
            if key in want:
                seen.add(key)
                new = f"{key}={want[key]}"
                dirty |= new != line
                out.append(new)
            else:
                out.append(line)
        for key in want:
            if key not in seen:
                out.append(f"{key}={want[key]}")
                dirty = True
        if dirty:
            imp.write_text("\n".join(out) + "\n")
            changed += 1
    return changed


def godot_import() -> bool:
    exe = shutil.which("godot") or shutil.which("godot4")
    if not exe:
        return False
    subprocess.run([exe, "--headless", "--import", "--path", str(ROOT)],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=900)
    return True


def neutralise(path: pathlib.Path, target: float = 0.72) -> None:
    """Flatten a colour cast out of an albedo so it can be tinted freely.

    Several excellent scans are strongly coloured (the book linen is dark olive).
    Multiplying a tint into one of those just darkens and muddies it, so for slots
    marked "neutralize" we rescale each channel to a neutral mid grey, keeping all
    the weave and wear detail but letting the per-prop tint decide the colour.
    """
    img = Image.open(path).convert("RGB")
    means = ImageStat.Stat(img).mean
    scale = [min(4.0, (target * 255.0) / max(m, 1.0)) for m in means]
    img = Image.merge("RGB", [c.point(lambda v, k=k: min(255, int(v * k)))
                              for c, k in zip(img.split(), scale)])
    save_jpg(img, path)


def flatten(path: pathlib.Path, contrast: float) -> None:
    """Pull every pixel of an albedo toward the map's mean colour, keeping `contrast` of its
    variation: for a finish more uniform than the scan it was taken from."""
    img = Image.open(path).convert("RGB")
    means = ImageStat.Stat(img).mean
    img = Image.merge("RGB", [c.point(lambda v, m=m: max(0, min(255, int(m + (v - m) * contrast))))
                              for c, m in zip(img.split(), means)])
    save_jpg(img, path)


def dielectric(path: pathlib.Path) -> None:
    """Zero the metallic channel. Powder coat and paint are dielectrics over steel, and a scan of
    painted metal can ship a metalness map of the steel under the paint."""
    r, g, _ = Image.open(path).convert("RGB").split()
    save_jpg(Image.merge("RGB", [r, g, Image.new("L", r.size, 0)]), path)


def write_meta(dest: pathlib.Path) -> None:
    """Record the means of the roughness and metallic maps, so `Mats.finish` can ask for a
    roughness in absolute terms: ORMMaterial3D multiplies the map by a scalar, and the maps'
    means run from 0.02 (polished granite) to 0.92 (terry)."""
    _, g, b = Image.open(dest / "orm.jpg").convert("RGB").split()
    (dest / "meta.json").write_text(json.dumps({
        "roughness": round(ImageStat.Stat(g).mean[0] / 255.0, 4),
        "metallic": round(ImageStat.Stat(b).mean[0] / 255.0, 4)}))


def main() -> int:
    force = "--force" in sys.argv
    manifest = json.loads((ROOT / "assets" / "textures.json").read_text())["textures"]
    OUT.mkdir(parents=True, exist_ok=True)
    failed = []
    for slot, spec in manifest.items():
        dest = OUT / slot
        # The stamp is everything that decides the pixels, so pointing a slot at another scan
        # re-fetches it; checking only that the files exist kept the old scan under the new name.
        stamp = json.dumps({k: v for k, v in spec.items() if k not in ("scale", "normal_scale", "note")},
                           sort_keys=True)
        stamp_file = dest / "source.json"
        if (not force and all((dest / f"{n}.jpg").exists() for n in ("albedo", "normal", "orm"))
                and stamp_file.exists() and stamp_file.read_text() == stamp):
            meta = dest / "meta.json"
            if not meta.exists() or "metallic" not in json.loads(meta.read_text()):
                write_meta(dest)
            print(f"  ok    {slot} (cached)")
            continue
        dest.mkdir(parents=True, exist_ok=True)
        try:
            source = spec.get("id") or spec.get("recipe")
            print(f"  fetch {slot:16s} {spec['src']}/{source} @ {spec.get('res', '-')}", flush=True)
            if spec["src"] == "generated":
                GENERATED[spec["recipe"]](slot, spec, dest)
            else:
                (fetch_polyhaven if spec["src"] == "polyhaven" else fetch_ambientcg)(slot, spec, dest)
            if spec.get("neutralize"):
                n = spec["neutralize"]
                neutralise(dest / "albedo.jpg", 0.72 if n is True else float(n))
            if "contrast" in spec:
                flatten(dest / "albedo.jpg", float(spec["contrast"]))
            if spec.get("dielectric"):
                dielectric(dest / "orm.jpg")
            write_meta(dest)
            stamp_file.write_text(stamp)
        except Exception as exc:  # keep going; report everything at the end
            print(f"  FAIL  {slot}: {exc}", flush=True)
            failed.append(slot)
    print(f"\n{len(manifest) - len(failed)}/{len(manifest)} slots ready in {OUT}")

    # Import once so Godot generates the .import files, patch them, then import again
    # so the corrected settings actually take effect.
    if godot_import():
        n = patch_imports()
        if n:
            print(f"corrected import settings on {n} textures; re-importing")
            godot_import()
    else:
        print("godot not on PATH - run it once to import, then re-run this script")
    if failed:
        print("failed: " + ", ".join(failed))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
