# Client Configuration

Connect your MCP client to tools deployed on MATLAB Production Server. MCP Framework builds HTTP-based MCP servers, so any client that supports HTTP transport connects directly. Clients that only support STDIO transport use the included [bridge](#stdio-bridge).

## Contents

- [Claude Code](#claude-code)
- [OpenAI Codex CLI](#openai-codex-cli)
- [Google Gemini CLI](#google-gemini-cli)
- [Claude Desktop](#claude-desktop)
- [Visual Studio Code](#visual-studio-code)
- [Any HTTP client](#any-http-client)
- [Protocol support](#protocol-support)
- [STDIO bridge](#stdio-bridge)
- [Troubleshooting](#troubleshooting)

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
url = "http://localhost:9910/principalStress/mcp"
```

Codex CLI infers the HTTP transport from `url`, so the entry needs no other key. Restart Codex CLI after editing. The tool appears in the MCP status display.

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

## Protocol Support

The server supports two MCP revisions, `2025-06-18` and `2026-07-28`, and serves each request by the revision it's written for. A client of either revision connects without configuration. Clients that ask for `2025-03-26` or `2024-11-05` are served as `2025-06-18`.

The server uses the Streamable HTTP transport in JSON-only mode. It never opens a server-sent events stream, so a client that requires one can't connect. See [Protocol Conformance](../concepts/protocol-conformance.md) for what each revision requires.

---

## STDIO Bridge

For clients that only support STDIO transport, MCP Framework includes `mcpstdio2http.py`. It forwards STDIO requests to an HTTP server and returns the responses.

The bridge works with either MCP revision. For a `2025-06-18` client, it sends back the session ID from `initialize` and ends the session when the client disconnects. For a `2026-07-28` client, it adds the `MCP-Protocol-Version`, `Mcp-Method` and `Mcp-Name` headers that the message body calls for.

```sh
python mcpstdio2http.py --url http://localhost:9910/principalStress/mcp
```

Flags:

| Flag | Default | Description |
| :--- | :--- | :--- |
| `--url` | `http://localhost:9910/mcp` | MCP endpoint, `http://<host>:<port>/<archive>/mcp`. The default names no archive, so always set it. |
| `--timeout` | `30` | Request timeout in seconds |
| `--log-level` | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR`, or `CRITICAL` |
| `--log-file` | `mcpstdio2http.py.log` | Name of the log file |
| `--log-dir` | The current folder | Folder for the log file. The MCP client must have write access to it. |

The bridge always writes a log file.

The bridge requires the `requests` Python package.

You do not call the bridge directly — configure your MCP client to launch it as a command (see the [Claude Desktop](#claude-desktop) example above).

---

## Troubleshooting

For the full request and response rules, see [Protocol Conformance](../concepts/protocol-conformance.md).

### Requests get HTTP 400

The body is a JSON-RPC error. Read `error.code`:

- **`-32022`: the client sends an unsupported `MCP-Protocol-Version`.** The server accepts `2025-06-18` (and `2025-03-26` and `2024-11-05`, served as `2025-06-18`) and `2026-07-28`. `error.data.supported` lists `2025-06-18` and `2026-07-28`. Update the client, or configure it to use one of those revisions.
- **`-32602` with "Cannot attribute the request to a protocol version": the server can't tell which revision the request is for.** A `2025-06-18` client that gets this after `initialize` isn't sending back `Mcp-Session-Id`. The server returns the session ID in a response header from `initialize`, and every later request must include it. Check that your client or proxy doesn't strip the header. A `2026-07-28` client must put `io.modelcontextprotocol/protocolVersion` in every request's `params._meta`.
- **`-32020`: a `2026-07-28` request has a missing or mismatched header.** `MCP-Protocol-Version` and `Mcp-Method` are required on every request, and `Mcp-Name` on `tools/call`, `resources/read` and `prompts/get`. Each must match the body.

### `GET` gets HTTP 405

That's expected. The server doesn't open server-to-client streams. A client that supports plain HTTP takes the 405 as its cue to continue without one.

### `tools/list` gets HTTP 500 with error `-32603`

The server couldn't load the archive's tool definitions. Read `error.message`. If it says to restart the server in multi-MCOS mode, set the environment variable `MW_MULTIMCOS_MODE` to `true` on the server machine and restart the server. See [Several Archives on One Server](../reference/deploy.md#several-archives-on-one-server). The same failure can appear on `tools/call`, `resources/list` and `resources/read`.

### A tool error arrives as HTTP 200

That's expected. When a tool raises a MATLAB error, the response is HTTP 200 with `result.isError` set to `true` and the error text in `result.content`. Check `result.isError`, not the HTTP status. See [Tool Errors](../concepts/protocol-conformance.md#tool-errors).

--- Copyright 2026 The MathWorks, Inc. ---
