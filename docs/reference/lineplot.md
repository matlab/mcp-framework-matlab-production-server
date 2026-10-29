# Simple Line Graphs with linePlot
`linePlot` is a FastMCP server that creates simple line graphs from CSV files. By default it uses the [STDIO transport](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports), which means it must run on the same machine as the MCP host. With `--port`, it serves HTTP on `localhost:<port>` instead.

The script is `Utilities/linePlot.py` in the MCP Framework installation. To start the server:
```sh
python linePlot.py [--port <port number>]
    [--log-level DEBUG | INFO | WARNING | ERROR | CRITICAL]
    [--log-dir <folder>] [--log-file <filename>]
```

| Option | Default | Description |
| :--- | :--- | :--- |
| `--port` | None (STDIO) | Serve HTTP on `localhost:<port>` instead of STDIO |
| `--log-level` | `INFO` | Detail of messages in the log file |
| `--log-dir` | The current folder | Folder for the log file |
| `--log-file` | `linePlot.py.log` | Name of the log file |

`linePlot` always writes a log file. The MCP host must have write access to the log folder; granting that access is typically a host-specific process.

`linePlot` primarily exists to demonstrate how to integrate multiple MCP tools into a single solution. For example, an LLM can call the `cleanSignal` tool from the [Periodic Noise](../../Examples/Periodic%20Noise/walkthrough.md) example to filter a signal into a CSV file, then call `linePlot` to graph the result.

`linePlot` requires the `FastMCP` and `matplotlib` Python packages.

--- Copyright 2025-2026 The MathWorks, Inc. ---
