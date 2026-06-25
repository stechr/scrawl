# Scrawl

Draw freehand on top of **any** app — slides, browser, video, terminal —
no matter which tool you present with (Teams, Zoom, Chime, …). Whatever is
shared on your display, your ink shows up too.

It's a tiny native macOS menu-bar app. No Xcode needed: build and run from the
terminal.

---

## Demo

See Scrawl in action — including an AI agent operating it through the control API:

- 🎬 Narrated walkthrough video: https://schristoph.online/media/scrawl-demo.mp4
- 📝 Announcement blog post: https://schristoph.online/blog/scrawl/

The demo shows the "two front doors, one core" idea: the same canvas driven by the human
toolbar and by an agent through the loopback control API + MCP wrapper.

---

## Quickstart

```bash
cd inkover
swift build -c release
swift run -c release        # or run the binary: .build/release/Scrawl
```

On launch you get:

- a **✏️ menu-bar icon** (top-right of the screen), and
- a **dark floating toolbar** at the bottom-centre of your main screen.

There is no Dock icon (it's a menu-bar / accessory app).

### Draw something

1. Click **✏️ Draw** in the toolbar (or press **⌃⌥D**). A **red frame**
   appears around the screen — that means draw mode is **on**.
2. Drag anywhere to draw. Pick a **colour** swatch and a width (**S / M / L**).
3. **Undo** removes the last stroke; **Clear** wipes everything.

### ⚠️ How to STOP drawing (important)

While drawing, the overlay captures your mouse, so you can't click other apps.
To get out, do **any** of these:

- Press **Esc** ← easiest, works from anywhere
- Click **👻 Ghost (Esc)** in the toolbar
- Press **⌃⌥D**
- Use the menu-bar **✏️ → Toggle Drawing**

The red frame disappears and clicks pass through to the app underneath again
(so you can advance slides, click links, etc.) while your ink stays on screen.

---

## Controls

| Action | Toolbar | Keyboard |
|--------|---------|----------|
| **Exit draw mode** | `👻 Ghost (Esc)` | **Esc** |
| Toggle Draw / Ghost | `✏️ Draw` ↔ `👻 Ghost` | `⌃⌥D` |
| Undo last stroke | `Undo` | `⌃⌥Z` |
| Clear all | `Clear` | `⌃⌥C` |
| Pick colour | colour swatches | — |
| Pen width | `S` / `M` / `L` | — |
| Fade mode (ink auto-disappears) | `⏱ Fade: Off/On` | — |
| Show/Hide toolbar | menu-bar ✏️ | — |
| Quit | `Quit` | menu-bar ✏️ → Quit |

**Two modes:**
- **Draw** — overlay captures the mouse; red frame shown; drag to draw.
- **Ghost** — clicks pass through to the app underneath; ink stays visible.

**Fade mode:** toggle **⏱ Fade** on, and each stroke you finish stays visible
for ~2s, then fades out and removes itself over ~1.5s — handy for quick
"circle this, move on" emphasis without clearing. Toggle it off for permanent
ink. (Timings are constants in `CanvasView.swift`.)

---

## Permissions

- **No Screen Recording permission needed.** Scrawl *overlays* the screen, it
  does not capture it.
- **Accessibility (optional):** the keyboard shortcuts (`⌃⌥D`, `Esc`, etc.)
  work globally — i.e. while another app is focused — only if you grant
  Accessibility: **System Settings → Privacy & Security → Accessibility**.
  The **toolbar buttons always work** without any permission, so this is
  optional.

---

## Using it in a screen share

The overlay appears in **whole-display** screen shares (Teams / Zoom / Chime
"Share screen"). It will **not** appear if you share a **single application
window** only — share the whole screen/display instead.

---

## Control API (drive it from a script or an AI agent)

Scrawl runs a **loopback-only** HTTP server on `127.0.0.1:7777` (disable with
`--no-serve`). POST a JSON command, or a **batch** under `commands` (preferred —
one request per scene keeps an agent efficient). Coordinates are **normalized
0–1 with a top-left origin**, so callers can reuse browser/Playwright element
boxes directly without pixel math.

```bash
# batch — one request, many annotations
curl -X POST 127.0.0.1:7777/draw -d '{"commands":[
  {"op":"circle","at":[0.6,0.3],"r":0.05,"color":"red","width":4},
  {"op":"arrow","from":[0.2,0.5],"to":[0.55,0.42],"color":"yellow"},
  {"op":"text","at":[0.3,0.7],"text":"look here","color":"white"}
]}'

# control
curl -X POST 127.0.0.1:7777/ -d '{"op":"mode","mode":"ghost"}'   # draw|ghost
curl -X POST 127.0.0.1:7777/ -d '{"op":"clear"}'
```

| op | fields |
|----|--------|
| `line` / `arrow` | `from:[x,y]`, `to:[x,y]` |
| `rect` / `ellipse` | `from:[x,y]`, `to:[x,y]` (opposite corners) |
| `circle` | `at:[x,y]`, `r` (fraction of screen height) |
| `freehand` | `points:[[x,y], …]` |
| `text` | `at:[x,y]`, `text` |
| `clear` | — |
| `mode` | `mode:"draw"` \| `"ghost"` |

Optional on any shape: `color` (name or `#RRGGBB`), `width` (points), `fade`
(bool — the annotation auto-disappears like fade mode).

> **Security note:** the control server binds **`127.0.0.1` only** and is
> **unauthenticated**. It can do exactly one thing — draw / clear / switch mode
> — with **no file or system access**. Any local process can therefore draw on
> your screen while Scrawl is running; pass `--no-serve` to turn it off.

## How it works

A transparent, borderless `NSPanel` at screen-saver window level covers the
screen and floats above normal windows and full-screen presentations
(`canJoinAllSpaces` + `fullScreenAuxiliary`). A `CanvasView` records freehand
strokes and renders them. The toolbar sits one level **above** the overlay so
its buttons stay clickable even while you're drawing. Switching to "ghost mode"
simply flips `window.ignoresMouseEvents`.

Source layout:

```
Package.swift
Sources/Scrawl/
  main.swift          # boots an accessory (menu-bar-only) AppKit app
  CanvasView.swift    # stroke model, drawing, transparent overlay panel
  AppDelegate.swift   # windows, toolbar, menu-bar item, hotkeys, mode toggle
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "I can't click anything / I'm stuck drawing" | Press **Esc**. You were in draw mode (red frame on). |
| Shortcuts don't work when another app is focused | Grant **Accessibility** permission (see above). Toolbar buttons still work. |
| Ink doesn't show in my screen share | Share the **whole screen/display**, not a single window. |
| Toolbar is off-screen / hidden | Menu-bar **✏️ → Show/Hide Toolbar**. Drag the toolbar to reposition (it's movable). |
| Overlay not on top of full-screen Keynote/PowerPoint | Tell me what you see — we may need to tweak the window level. |

---

## Roadmap (not in MVP)

- Multi-monitor overlays (currently the main screen only)
- Shapes (arrow / line / rectangle / ellipse) and a text tool
- Per-stroke eraser, spotlight / zoom
- Snapshot export (PNG / PDF)
- A packaged, signed `.app` bundle (double-click to launch)

## License

MIT (see LICENSE).
