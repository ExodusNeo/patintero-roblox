# "Kanto Night" UI art: rasterizes the hand-drawn Figma shapes in assets/ui/kanto/src/*.svg
# (exported from the "Patintero UI" Figma file, Direction B) to tintable PNGs in assets/ui/kanto/.
# Each shape is drawn in one color; it is recolored white and its opacities are scaled so the
# strongest stroke is opaque, then Roblox tints it (ImageColor3) and fades it (ImageTransparency).
# Needs Google Chrome (headless) for the rasterizing, so blur filters render like they do in Figma.
#   python tools/ui_kanto.py
import re
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC, OUT = ROOT / "assets/ui/kanto/src", ROOT / "assets/ui/kanto"
CHROME = r"C:\Program Files\Google\Chrome\Application\chrome.exe"
# Roblox caps images at 1024 px; big soft shapes need no extra resolution anyway
SCALE = {"light_cone": 1, "light_pool": 1, "ground_shadow": 1, "callout_paint": 1.5, "chalk_underline": 1.5}
OPACITY = re.compile(r'\b(fill-opacity|stroke-opacity|stop-opacity|opacity)="([\d.]+)"')
COLOR = re.compile(r'\b(fill|stroke|stop-color)="(#[0-9A-Fa-f]{6}|black|white)"')


def alpha(tag: str) -> float:
    m = OPACITY.search(tag)
    return float(m[2]) if m else 1.0  # no opacity attribute: fully opaque


def whiten(svg: str) -> str:
    # Strongest opacity among the drawn shapes (gradient-filled shapes count through their stops)
    tags = re.findall(r"<(?:path|rect|ellipse|circle|stop)\b[^>]*>", svg)
    top = max((alpha(t) for t in tags if not re.search(r'(?:fill|stroke)="url\(', t)), default=1.0)
    svg = OPACITY.sub(lambda m: f'{m[1]}="{min(float(m[2]) / top, 1):.3f}"', svg)
    return COLOR.sub(lambda m: f'{m[1]}="#FFFFFF"', svg)


def main():
    with tempfile.TemporaryDirectory() as tmp:
        for src in sorted(SRC.glob("*.svg")):
            svg = whiten(src.read_text(encoding="utf-8"))
            w, h = re.search(r'width="([\d.]+)" height="([\d.]+)"', svg).groups()
            page = Path(tmp) / src.name
            page.write_text(svg, encoding="utf-8")
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            "--default-background-color=00000000", f"--force-device-scale-factor={SCALE.get(src.stem, 2)}",
                            f"--window-size={round(float(w))},{round(float(h))}", f"--screenshot={OUT / (src.stem + '.png')}",
                            page.as_uri()], check=True, capture_output=True)
            print("wrote", src.stem + ".png")


if __name__ == "__main__":
    main()
