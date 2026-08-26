# Client Configuration

Connect your MCP client to tools deployed on MATLAB Production Server. MCP Framework builds HTTP-based MCP servers, so any client that supports HTTP transport connects directly. Clients that only support STDIO transport use the included [bridge](#stdio-bridge).

## Contents

- [Claude Code](#claude-code)
- [OpenAI Codex CLI](#openai-codex-cli)
- [Google Gemini CLI](#google-gemini-cli)
- [Claude Desktop](#claude-desktop)
- [Visual Studio Code](#visual-studio-code)
- [Any HTTP client](#any-http-client)
- [STDIO bridge](#stdio-bridge)

---

## Claude Code

Claude Code connects directly to HTTP MCP servers. Add your tool to the project-scoped `.mcp.json`:

```json
{
  "mcpServers": {
    "principalStress": {
      "type": "http",
      "url": "http://localhost:9910/principalStress/mcp"
    }
  }
}
```

Restart Claude Code after editing the file. Confirm the server loaded with `/mcp`.

To add multiple tools from different servers:

```json
{
  "mcpServers": {
    "principalStress": {
      "type": "http",
      "url": "http://localhost:9910/principalStress/mcp"
    },
    "cleanSignal": {
      "type": "http",
      "url": "http://localhost:9910/cleanSignal/mcp"
    }
  }
}
```

You can also add servers from the command line:

```sh
claude mcp add --transport http principalStress http://localhost:9910/principalStress/mcp
```

---

## OpenAI Codex CLI

Codex CLI reads MCP server configuration from `~/.codex/config.toml`. Add an HTTP server:

```toml
[mcp_servers.principalStress]
type = "http"
url = "http://localhost:9910/principalStress/mcp"
```

Restart Codex CLI after editing. The tool appears in the MCP status display.

---

## Google Gemini CLI

Gemini CLI reads MCP configuration from `.gemini/settings.json` in your project directory or `~/.gemini/settings.json` globally:

```json
{
  "mcpServers": {
    "principalStress": {
      "httpUrl": "http://localhost:9910/principalStress/mcp"
    }
  }
}
```

Restart Gemini CLI after editing. Confirm with `/mcp`.

---

## Claude Desktop

Claude Desktop requires STDIO transport. Use the included [STDIO bridge](#stdio-bridge) to connect to your HTTP server.

Add this to your Claude Desktop configuration file (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "principalStress": {
      "command": "python",
      "args": [
        "/path/to/mcp-framework-matlab-production-server/Utilities/mcpstdio2http.py",
        "--url", "http://localhost:9910/principalStress/mcp"
      ]
    }
  }
}
```

Replace `/path/to/` with the actual install location of MCP Framework.

Quit and restart Claude Desktop after editing (closing the window is not enough — quit the application).

---

## Visual Studio Code

VS Code with GitHub Copilot connects directly to HTTP MCP servers. Create a `.vscode/mcp.json` file in your project:

```json
{
  "servers": {
    "principalStress": {
      "url": "http://localhost:9910/principalStress/mcp",
      "type": "http"
    }
  }
}
```

VS Code shows a status decoration above each server name in `mcp.json`. Confirm both show as connected.

---

## Any HTTP Client

Point any MCP client that supports HTTP transport at the endpoint URL. The URL pattern is:

```
http://<host>:<port>/<serverName>/mcp
```

No bridge or adapter needed. The server speaks standard MCP-over-HTTP (JSON-RPC).

---

## STDIO Bridge

For clients that only support STDIO transport, MCP Framework includes `mcpstdio2http.py`. It forwards STDIO requests to an HTTP server and returns the responses.

```sh
python mcpstdio2http.py --url http://localhost:9910/principalStress/mcp
```

Optional flags:

| Flag | Description |
| :--- | :--- |
| `--log-level` | `DEBUG`, `INFO`, `WARNING`, `ERROR`, or `CRITICAL` |
| `--log-dir` | Directory for log files (the MCP client must have write access) |
| `--timeout` | Request timeout in seconds |

The bridge requires the `requests` Python package.

You don't call the bridge directly — configure your MCP client to launch it as a command (see the [Claude Desktop](#claude-desktop) example above).

--- Copyright 2026 The MathWorks, Inc. ---
