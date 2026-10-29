# Connecting MCP STDIO Hosts to HTTP Servers
Some MCP hosts only support the STDIO protocol and cannot connect to MCP servers via HTTP. `mcpstdio2http` bridges that gap: it forwards STDIO requests to an HTTP server and formats HTTP responses back to STDIO. It is content-agnostic, meaning it does no filtering in either direction.

The script is `Utilities/mcpstdio2http.py` in the MCP Framework installation. To start the server proxy:
```sh
python mcpstdio2http.py [--url <MCP Server URL>] [--timeout <seconds>]
    [--log-level DEBUG | INFO | WARNING | ERROR | CRITICAL]
    [--log-dir <folder>] [--log-file <filename>]
```

| Option | Default | Description |
| :--- | :--- | :--- |
| `--url` | `http://localhost:9910/mcp` | MCP endpoint, `http://<host>:<port>/<archive>/mcp`. The default names no archive, so always set it. |
| `--timeout` | 30 | Seconds to wait for each HTTP response |
| `--log-level` | `INFO` | Detail of messages in the log file |
| `--log-dir` | The current folder | Folder for the log file |
| `--log-file` | `mcpstdio2http.py.log` | Name of the log file |

The bridge always writes a log file. The MCP host must have write access to the log folder; granting that access is typically a host-specific process.

The bridge works with servers under either protocol revision. It passes each message through unchanged and adds the headers the revision needs: `Mcp-Session-Id` for `2025-06-18`, and `MCP-Protocol-Version`, `Mcp-Method` and `Mcp-Name` for `2026-07-28`. See [Protocol Conformance](../concepts/protocol-conformance.md).

The `--url` argument specifies the HTTP server. To connect to the `primeSequence` MCP server running on `http://localhost:9910`, specify the `primeSequence` MCP server endpoint:
```sh
python mcpstdio2http.py --url http://localhost:9910/primeSequence/mcp
```

`mcpstdio2http.py` requires the `requests` Python package.

--- Copyright 2025-2026 The MathWorks, Inc. ---
