# Scrawl MCP server

A thin, **batch-first** MCP wrapper over Scrawl's loopback control server
(`http://127.0.0.1:7777`). It lets an MCP-capable agent draw annotations on top
of any app while Scrawl is running.

## Tools

| Tool | What it does |
|------|--------------|
| `scrawl_draw(commands=[…])` | Draw a batch of annotations (circle/arrow/line/rect/ellipse/freehand/text). Coords are normalized 0–1, top-left origin. |
| `scrawl_clear()` | Remove all annotations. |
| `scrawl_set_mode("draw"\|"ghost")` | Switch capture vs click-through. |

See the docstrings in `scrawl_mcp.py` for the full command schema.

## Prerequisites

- **[uv](https://docs.astral.sh/uv/)** (bundles its own Python; macOS has no
  reliable system Python). Install: `curl -LsSf https://astral.sh/uv/install.sh | sh`
- The **Scrawl app running** (the control server is on by default; `--no-serve`
  disables it).

## Run standalone

```bash
uv run mcp/scrawl_mcp.py
```

`uv` fetches the `mcp` SDK automatically from the inline script header.

## Register with Kiro CLI

Add to `~/.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "scrawl": {
      "command": "uv",
      "args": ["run", "--quiet", "/ABSOLUTE/PATH/TO/scrawl-priv/mcp/scrawl_mcp.py"]
    }
  }
}
```

Restart your Kiro session to load it. Then the agent can call `scrawl_draw`,
`scrawl_clear`, and `scrawl_set_mode`.

> Set `SCRAWL_PORT` in the env if you changed Scrawl's port.
