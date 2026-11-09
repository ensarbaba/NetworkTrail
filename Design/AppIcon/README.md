# NetworkTrail app icon

These SVG files are the layers of the Mac app icon. The icon file is `Apps/Mac/Sources/AppIcon.icon`. It contains copies of these layers in `Assets/`.

## Layers

Each layer is a 1024 × 1024 canvas. The icon shows three requests as rows with a gap between them, and a status code in each row. Each row starts 112 units to the right of the row above it. The colors are teal for 2xx, sky for 3xx, and orange for 4xx. The app uses the same system orange for slow requests.

| File | Content | Position (x, y, width × height) |
|---|---|---|
| `row-1.svg` | row, `#2BD4B0` (teal) | 72, 138, 600 × 228 |
| `row-2.svg` | row, `#38B6F6` (sky) | 184, 398, 560 × 228 |
| `row-3.svg` | row, `#FF9F0A` (orange) | 296, 658, 656 × 228 |
| `codes.svg` | `200`, `302`, `404` in white | left edges at x = 158.6, 270.6, 382.6; cap height 109 |

The digits are outlines of JetBrains Mono Bold (SIL Open Font License 1.1). The SVG files contain no text and need no font.

## Icon Composer settings

- Background: automatic gradient, `srgb:0.07059,0.15686,0.23137` (deep ink).
- Group 1 (top): `codes`. Liquid Glass on.
- Group 2: `row-3`, `row-2`, `row-1`, from top to bottom. Each layer: Liquid Glass on, opacity 85 %.
- Each group: shadow neutral 50 %, translucency off.
- Platform: macOS only.

## Change the icon

1. Edit the SVG files in this folder.
2. Copy the changed files to `Apps/Mac/Sources/AppIcon.icon/Assets/`.
3. Open `Apps/Mac/Sources/AppIcon.icon` in Icon Composer (Xcode > Open Developer Tool > Icon Composer) to examine the result.

To make PNG previews without the GUI, use the `ictool` in Icon Composer:

```bash
"/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool" Apps/Mac/Sources/AppIcon.icon --export-image --output-file /tmp/AppIcon-Dark.png --platform macOS --rendition Dark --width 1024 --height 1024 --scale 1
```

Renditions: `Default`, `Dark`, `TintedLight`, `TintedDark`, `ClearLight`, `ClearDark`.
