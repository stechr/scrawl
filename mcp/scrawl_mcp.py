#!/usr/bin/env -S uv run --quiet
# /// script
# requires-python = ">=3.10"
# dependencies = ["mcp>=1.2.0"]
# ///
"""
Scrawl MCP server — a thin, batch-first wrapper over Scrawl's loopback control
server (http://127.0.0.1:7777). Lets an MCP agent draw annotations on top of
any app while Scrawl is running.

It uses only the Python standard library to talk to Scrawl (urllib), so the
only third-party dependency is the MCP SDK itself (fetched by `uv`).

Run directly:   uv run mcp/scrawl_mcp.py
Or register in ~/.kiro/settings/mcp.json (see mcp/README.md).
"""
import json
import os
import urllib.request
import urllib.error

from mcp.server.fastmcp import FastMCP

PORT = int(os.environ.get("SCRAWL_PORT", "7777"))
BASE = f"http://127.0.0.1:{PORT}/"
# Defense-in-depth: this client only ever talks to the local Scrawl control
# server. Refuse anything that is not a plain http loopback URL.
if not BASE.startswith(("http://127.0.0.1:", "http://localhost:")):
    raise SystemExit(f"refusing non-loopback Scrawl URL: {BASE}")

mcp = FastMCP("scrawl")


def _post(payload: dict) -> dict:
    """POST a command payload to Scrawl; return its JSON response (or an error)."""
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        BASE, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        # BASE is a validated, hardcoded http loopback URL (see guard above), so
        # opening it cannot reach file:// or a custom scheme.
        with urllib.request.urlopen(req, timeout=4) as resp:  # nosec B310
            return json.loads(resp.read().decode())
    except urllib.error.URLError as e:
        return {
            "ok": False,
            "error": f"could not reach Scrawl on {BASE} ({e}). "
            "Is the Scrawl app running (and not started with --no-serve)?",
        }
    except Exception as e:  # noqa: BLE001
        return {"ok": False, "error": str(e)}


@mcp.tool()
def scrawl_draw(commands: list[dict]) -> dict:
    """Draw one or more annotations on top of whatever is on screen, in a single
    batch (preferred — send all annotations for a "scene" in one call).

    Coordinates are NORMALIZED 0..1 with a TOP-LEFT origin: [0,0] is the
    top-left of the main screen, [1,1] the bottom-right. (These match a web
    page / Playwright bounding box once divided by the screen size.)

    Each command is an object with an "op" and its fields:

      {"op":"circle","at":[x,y],"r":0.05}              # r = fraction of screen height
      {"op":"arrow","from":[x,y],"to":[x,y]}
      {"op":"line","from":[x,y],"to":[x,y]}
      {"op":"rect","from":[x,y],"to":[x,y]}            # opposite corners
      {"op":"ellipse","from":[x,y],"to":[x,y]}
      {"op":"freehand","points":[[x,y],[x,y], ...]}
      {"op":"text","at":[x,y],"text":"look here"}

    Optional on any shape:
      "color": a name (red|blue|green|yellow|orange|black|white) or "#RRGGBB"
      "width": stroke width in points (default 4)
      "fade":  true  -> the annotation fades out and disappears after a few seconds

    Example:
      scrawl_draw(commands=[
        {"op":"circle","at":[0.62,0.30],"r":0.05,"color":"red","width":4},
        {"op":"arrow","from":[0.20,0.50],"to":[0.55,0.42],"color":"yellow"},
        {"op":"text","at":[0.30,0.70],"text":"the agent does the boring part"}
      ])
    """
    return _post({"commands": commands})


@mcp.tool()
def scrawl_clear() -> dict:
    """Remove all annotations currently on screen."""
    return _post({"op": "clear"})


@mcp.tool()
def scrawl_set_mode(mode: str) -> dict:
    """Set Scrawl's interaction mode.

    mode="ghost" -> clicks pass through to the app underneath (annotations stay
                    visible). Use this for agent-drawn annotations so the mouse
                    is not captured.
    mode="draw"  -> the overlay captures the mouse for manual freehand drawing.
    """
    return _post({"op": "mode", "mode": mode})


if __name__ == "__main__":
    mcp.run()
