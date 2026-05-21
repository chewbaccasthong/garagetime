#!/usr/bin/env python3
"""Generate colorset directories in Assets.xcassets/Colors/ for every GarageTime theme token."""
import json
import os
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent / "GarageTime" / "Assets.xcassets" / "Colors"
ROOT.mkdir(parents=True, exist_ok=True)

# token name -> (dark hex, light hex). All sRGB. Hex includes leading #.
TOKENS = {
    # backgrounds — near-black in dark, near-white in light
    "bg.primary":     ("#0E0E10", "#FAFAF7"),
    "bg.secondary":   ("#17171B", "#F1F1ED"),
    "bg.tertiary":    ("#1F1F25", "#E8E8E2"),
    "bg.elevated":    ("#26262D", "#FFFFFF"),
    "bg.overlay":     ("#000000B3", "#1117004D"),  # semi-transparent

    # surface accents
    "divider":        ("#2A2A30", "#D8D8D2"),
    "shimmer":        ("#33333A", "#E0E0DA"),

    # text
    "text.primary":   ("#ECECEE", "#101013"),
    "text.secondary": ("#A6A6AE", "#5A5A62"),
    "text.tertiary":  ("#7A7A82", "#8A8A90"),
    "text.inverse":   ("#101013", "#FAFAF7"),
    "text.onAccent":  ("#0E0E10", "#0E0E10"),

    # brand
    "accent.primary":   ("#FF6B35", "#E25826"),  # brake-light amber
    "accent.secondary": ("#3A3D45", "#5C606A"),  # steel graphite
    "accent.tertiary":  ("#FFB089", "#FFCDB3"),  # soft amber wash

    # status
    "status.green":     ("#4ADE80", "#27A94F"),
    "status.amber":     ("#FACC15", "#C99B00"),
    "status.red":       ("#F87171", "#D04545"),
    "status.blue":      ("#60A5FA", "#2C7BD7"),

    # destructive
    "destructive":      ("#F87171", "#C03030"),
}


def hex_to_components(hex_value: str) -> dict:
    """Convert a #RRGGBB or #RRGGBBAA hex string to asset-catalog component dict."""
    h = hex_value.lstrip("#")
    if len(h) == 6:
        r, g, b, a = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255
    elif len(h) == 8:
        r, g, b, a = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), int(h[6:8], 16)
    else:
        raise ValueError(f"Bad hex: {hex_value}")
    return {
        "alpha": f"{a/255:.3f}",
        "blue":  f"{b/255:.3f}",
        "green": f"{g/255:.3f}",
        "red":   f"{r/255:.3f}",
    }


def colorset_payload(dark_hex: str, light_hex: str) -> dict:
    return {
        "colors": [
            {
                "color": {
                    "color-space": "srgb",
                    "components": hex_to_components(light_hex),
                },
                "idiom": "universal",
            },
            {
                "appearances": [
                    {"appearance": "luminosity", "value": "dark"}
                ],
                "color": {
                    "color-space": "srgb",
                    "components": hex_to_components(dark_hex),
                },
                "idiom": "universal",
            },
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }


def main() -> None:
    for token, (dark, light) in TOKENS.items():
        # Convert dotted token to folder path: bg.primary -> bg/primary.colorset
        if "." in token:
            namespace, name = token.split(".", 1)
            ns_dir = ROOT / namespace
            ns_dir.mkdir(exist_ok=True)
            (ns_dir / "Contents.json").write_text(json.dumps({
                "info": {"author": "xcode", "version": 1},
                "properties": {"provides-namespace": True},
            }, indent=2) + "\n")
            target = ns_dir / f"{name}.colorset"
        else:
            target = ROOT / f"{token}.colorset"
        target.mkdir(exist_ok=True)
        (target / "Contents.json").write_text(
            json.dumps(colorset_payload(dark, light), indent=2) + "\n"
        )
        print(f"✓ {token}")


if __name__ == "__main__":
    main()
