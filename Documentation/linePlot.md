# Simple Line Graphs with linePlot
`linePlot` is a FastMCP server that creates simple line graphs from CSV files. It uses the [STDIO server protocol](https://modelcontextprotocol.io/specification/2025-06-18/basic/transports), which means it must run on the same machine as the MCP host. 

To start the server:
```sh
  python linePlot.py"
      --log-level DEBUG | INFO | WARNING | ERROR | CRITICAL
	  --log-dir <folder>
	  --timeout <seconds>
```
Logging is optional, but highly recommended. Your MCP host must have write access to the log directory; granting that access is typically a host-specific process.

 `linePlot` primarily exists to demonstrate how to integrate multiple MCP tools into a single solution. The [cleanSignal](../Examples/Periodic%20Noise/PeriodicNoise.md) example combines file system access with the `linePlot` and `cleanSignal` MCP tools to show that LLMs can manage intermediate results automatically.

Note that `linePlot` requires the `FastMCP` and `matplotlib` Python packages.
