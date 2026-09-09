#!/usr/bin/env python3
"""Download every texture named in assets/textures.json and normalise it for Godot.

Both sources are CC0, so nothing here needs an account, an API key or attribution.
Each slot ends up as assets/textures/<slot>/{albedo,normal,orm}.jpg, where `orm`
packs ambient occlusion, roughness and metallic into R, G and B - exactly the
layout Godot's ORMMaterial3D expects. Poly Haven already ships that packing as
its `arm` map; ambientCG ships the channels separately, so we pack them here.

    python3 tools/fetch_textures.py            # fetch anything missing
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


def main() -> int:
    force = "--force" in sys.argv
    manifest = json.loads((ROOT / "assets" / "textures.json").read_text())["textures"]
    OUT.mkdir(parents=True, exist_ok=True)
    failed = []
    for slot, spec in manifest.items():
        dest = OUT / slot
        if not force and all((dest / f"{n}.jpg").exists() for n in ("albedo", "normal", "orm")):
            print(f"  ok    {slot} (cached)")
            continue
        dest.mkdir(parents=True, exist_ok=True)
        try:
            print(f"  fetch {slot:16s} {spec['src']}/{spec['id']} @ {spec['res']}", flush=True)
            (fetch_polyhaven if spec["src"] == "polyhaven" else fetch_ambientcg)(slot, spec, dest)
            if spec.get("neutralize"):
                neutralise(dest / "albedo.jpg")
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
