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
cd ~/projects/scrawl-priv
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
2. Pick a **tool** — **✎ Pen** (freehand, default), **╱ Line**, **▭ Rect**,
   or **◯ Ellipse** — then drag to draw. Pick a **colour** swatch and a width
   (**S / M / L**).
3. **Hold Shift while dragging** to constrain: the Pen and Line snap to a
   straight line at the nearest 0/45/90°; Rect and Ellipse constrain to a
   square / circle.
4. **Undo** removes the last item (stroke or shape); **Clear** wipes everything.
5. **📷 Save** exports the canvas to `~/Pictures/Scrawl/` (see *Snapshot* below).

### Shape tools

- **✎ Pen** — freehand sketch. Hold **Shift** for a straight, angle-snapped line.
- **╱ Line** — drag from start to end. Hold **Shift** to snap the angle.
- **▭ Rect** — drag one corner to the opposite corner (rubber-band preview).
  Hold **Shift** for a square.
- **◯ Ellipse** — drag corner-to-corner for a free oval. Hold **Shift** for a circle.

The active tool is highlighted on the toolbar. Strokes and shapes share the same
sketchy stroke style, colour, and width.

### Snapshot / export (📷 Save)

**📷 Save** (or **⌃⌥S**) writes a timestamped PNG to `~/Pictures/Scrawl/`
(`scrawl-YYYYMMDD-HHMMSS.png`, folder created on first use):

- **Default — drawing only:** a *transparent* PNG of just your ink. Needs **no
  permission** and always works.
- **Optional — flattened with background:** if you grant **Screen Recording**
  permission (and are on **macOS 14+**), Scrawl composites your ink over a
  ScreenCaptureKit grab of the desktop behind the overlay. Without the
  permission (or on older macOS) it **falls back gracefully** to the
  drawing-only PNG. The first Save without permission triggers the system
  prompt; grant it and Save again to get the flattened image.

The toolbar button briefly shows **Saved ✓**; the saved path is also logged.

### Hide / show the toolbar

The floating toolbar can be tucked away when it's in the way while the app keeps
running in the menu bar:

- **Hide:** menu-bar **✏️ → Hide Toolbar** (or **⌃⌥H**).
- **Show:** **click the ✏️ menu-bar icon** (a click restores a hidden toolbar),
  or use **✏️ → Show Toolbar** / **⌃⌥H**. It reappears at its last position.

When the toolbar is visible, clicking the ✏️ menu-bar icon opens the menu as usual.

### Preferences (configurable shortcuts)

All keyboard shortcuts are stored in **`~/.scrawl/shortcuts.json`** (written with
the defaults on first run). Open **✏️ → Preferences…** for a small window to
view/edit each binding as `action -> shortcut` (e.g. `ctrl+opt+d`); **Save**
re-registers the global hotkeys immediately and updates the file. Modifiers:
`ctrl`, `opt`, `cmd`, `shift`. (**Esc** to exit draw mode is fixed and not
re-bindable.)

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

| Action | Toolbar | Keyboard (default) |
|--------|---------|--------------------|
| **Exit draw mode** | `👻 Ghost (Esc)` | **Esc** (fixed) |
| Toggle Draw / Ghost | `✏️ Draw` ↔ `👻 Ghost` | `⌃⌥D` |
| Tool: Pen / Line / Rect / Ellipse | `✎` / `╱` / `▭` / `◯` | `⌃⌥P` / `⌃⌥L` / `⌃⌥R` / `⌃⌥E` |
| Straight / constrained shape | hold **Shift** while dragging | — |
| Undo last item | `Undo` | `⌃⌥Z` |
| Clear all | `Clear` | `⌃⌥C` |
| Pick colour | colour swatches | — |
| Pen width | `S` / `M` / `L` | — |
| Fade mode (ink auto-disappears) | `⏱ Fade: Off/On` | `⌃⌥F` |
| Save snapshot (PNG) | `📷 Save` | `⌃⌥S` |
| Show / Hide toolbar | menu-bar ✏️ (click restores) | `⌃⌥H` |
| Preferences (edit shortcuts) | menu-bar ✏️ → Preferences… | — |
| Quit | `Quit` | menu-bar ✏️ → Quit |

Keyboard shortcuts are configurable in `~/.scrawl/shortcuts.json` (see
**Preferences** above); the table shows the defaults.

**Two modes:**
- **Draw** — overlay captures the mouse; red frame shown; drag to draw.
- **Ghost** — clicks pass through to the app underneath; ink stays visible.

**Fade mode:** toggle **⏱ Fade** on, and each stroke you finish stays visible
for ~2s, then fades out and removes itself over ~1.5s — handy for quick
"circle this, move on" emphasis without clearing. Toggle it off for permanent
ink. (Timings are constants in `CanvasView.swift`.)

---

## Permissions

- **No Screen Recording permission needed for drawing.** Scrawl *overlays* the
  screen, it does not capture it. The default **📷 Save** (transparent
  drawing-only PNG) also needs **no** permission.
- **Screen Recording (optional, for flattened Save):** to save a snapshot
  *flattened with the background behind your ink*, grant **System Settings →
  Privacy & Security → Screen Recording** (macOS 14+). Without it, Save falls
  back to the transparent drawing-only PNG.
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
  CanvasView.swift    # stroke/shape model, tools, drawing, transparent overlay
  AppDelegate.swift   # windows, toolbar, menu-bar item, hotkeys, mode toggle
  ControlServer.swift # loopback 127.0.0.1:7777 HTTP control API
  Shortcuts.swift     # Shortcut model + ~/.scrawl/shortcuts.json config
  Preferences.swift   # small shortcut-editing window
  Snapshot.swift      # PNG export (transparent ink + optional SCK flatten)
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "I can't click anything / I'm stuck drawing" | Press **Esc**. You were in draw mode (red frame on). |
| Shortcuts don't work when another app is focused | Grant **Accessibility** permission (see above). Toolbar buttons still work. |
| Ink doesn't show in my screen share | Share the **whole screen/display**, not a single window. |
| Toolbar is off-screen / hidden | Click the **✏️ menu-bar icon** to restore it (or **✏️ → Show Toolbar**, or **⌃⌥H**). Drag the toolbar to reposition (it's movable). |
| Overlay not on top of full-screen Keynote/PowerPoint | Tell me what you see — we may need to tweak the window level. |

---

## Roadmap (not in MVP)

- Multi-monitor overlays (currently the main screen only)
- Per-stroke eraser, spotlight / zoom
- Text tool on the human toolbar (the control API already supports `text`)
- A packaged, signed `.app` bundle (double-click to launch)

Recently added: shape tools (line / rectangle / ellipse), Shift-straight /
constrained drawing, snapshot/PNG export, hide/show toolbar, and configurable
shortcuts.

## License

MIT (see LICENSE).
