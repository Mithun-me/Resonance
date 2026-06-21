# Resonance — design assets

Editable sources for the app's visual identity.

## App icon

The icon is **Resonance Rings** — concentric ripples around a core pulse, expressing
the name (sound resonating outward). Three appearances ship in
`MithunMusicApp/Assets.xcassets/AppIcon.appiconset`:

| Source SVG | Appearance | Look |
|------------|------------|------|
| `AppIcon/icon-light.svg`  | Light / default | indigo → magenta gradient, white rings |
| `AppIcon/icon-dark.svg`   | Dark            | deep plum gradient, white rings |
| `AppIcon/icon-tinted.svg` | Tinted          | grayscale on dark (iOS applies the user's tint) |

The same ring motif (and the indigo→magenta gradient) is reused by the in-app
launch splash (`MithunMusicApp/Views/SplashView.swift`).

### Regenerating the PNGs

There's no SVG rasterizer beyond QuickLook on a stock macOS box, so the 1024×1024
PNGs are produced with `qlmanage`:

```sh
qlmanage -t -s 1024 -o . AppIcon/icon-light.svg
# → icon-light.svg.png ; rename to AppIcon-1024.png and drop into the appiconset
```

Repeat for `icon-dark.svg` → `AppIcon-Dark-1024.png` and `icon-tinted.svg` →
`AppIcon-Tinted-1024.png`. The filenames are wired in `AppIcon.appiconset/Contents.json`.
