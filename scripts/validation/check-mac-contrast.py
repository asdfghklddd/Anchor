#!/usr/bin/env python3
"""Check macOS information text against the actual light/dark asset colors."""

import json
import re
from pathlib import Path

DESIGN = Path(__file__).resolve().parents[2] / "Packages/AnchorKit/Sources/AnchorDesign"
ASSETS = DESIGN / "Resources/Colors.xcassets"
PALETTE = (DESIGN / "AnchorPalette.swift").read_text()
FOREGROUNDS = (
    "MintInk", "DeepSeaInk", "Interaction", "BrandDeep", "SourceCoralInk", "SourceCyanInk",
    "SourcePeriwinkleInk", "SourceSandInk", "SourceSeafoamInk",
)


def asset(name, dark):
    colors = json.loads((ASSETS / f"{name}.colorset/Contents.json").read_text())["colors"]
    for entry in colors:
        is_dark = {"appearance": "luminosity", "value": "dark"} in entry.get("appearances", [])
        if is_dark == dark:
            components = entry["color"]["components"]
            assert float(components["alpha"]) == 1, f"{name} needs alpha compositing"
            return tuple(float(components[channel]) for channel in ("red", "green", "blue"))
    raise AssertionError(f"Missing {'dark' if dark else 'light'} appearance: {name}")


def fixed_color(name):
    match = re.search(
        rf"static let {name} = Color\(red: ([\d.]+), green: ([\d.]+), blue: ([\d.]+)\)",
        PALETTE,
    )
    assert match, f"Cannot resolve fixed palette color: {name}"
    return tuple(map(float, match.groups()))


def composite(foreground, background, opacity):
    return tuple(f * opacity + b * (1 - opacity) for f, b in zip(foreground, background))


def luminance(rgb):
    linear = [v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in rgb]
    return sum(v * w for v, w in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast(foreground, background):
    low, high = sorted((luminance(foreground), luminance(background)))
    return (high + 0.05) / (low + 0.05)


def main():
    checks = []
    for dark in (False, True):
        mode = "dark" if dark else "light"
        backgrounds = {name: asset(name, dark) for name in ("FluoriteSurface", "Canvas", "Surface", "Paper")}
        # Bound the workspace gradient, including its brightest endpoint.
        backgrounds["Workspace/softBlue"] = composite(asset("SoftBlue", dark), backgrounds["Canvas"], 0.34)
        backgrounds["Workspace/aiBlue"] = composite(asset("AIBlue", dark), backgrounds["Canvas"], 0.12)
        for name in FOREGROUNDS:
            assert f'Color("{name}", bundle: .module)' in PALETTE, f"Unused foreground asset: {name}"
            for background_name, background in backgrounds.items():
                checks.append((f"{mode}: {name}/{background_name}", contrast(asset(name, dark), background)))
        checks.append((f"{mode}: badge deepSea/sand", contrast(fixed_color("deepSea"), fixed_color("sand"))))

    failures = [(label, ratio) for label, ratio in checks if ratio < 4.5]
    for label, ratio in failures:
        print(f"FAIL {label}: {ratio:.2f}:1")
    assert not failures, f"{len(failures)} text pairs failed WCAG AA"
    label, minimum = min(checks, key=lambda item: item[1])
    print(f"PASS: {len(checks)} light/dark text pairs; minimum {minimum:.2f}:1 ({label})")
    print(f"Badge: {contrast(fixed_color('deepSea'), fixed_color('sand')):.2f}:1 in both appearances")


if __name__ == "__main__":
    main()
