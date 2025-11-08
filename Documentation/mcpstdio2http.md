# Connecting MCP STDIO Hosts to HTTP Servers
Some MCP hosts only support the STDIO protocol and cannot connect to MCP servers via HTTP. `mcpstdio2http` bridges that gap: it forwards STDIO requests to an HTTP server and formats HTTP responses back to STDIO. It is content-agnostic -- that is, it does no filtering in either direction.

To start the server proxy:
```sh
  python mcpstdio2http.py"
    --log-level DEBUG | INFO | WARNING | ERROR | CRITICAL
	  --log-dir <folder>
    --url <MCP Server URL>
	  --timeout <seconds>
```
Logging is optional, but highly recommended. Your MCP host must have write access to the log directory; granting that access is typically a host-specific process.

The `--url` argument specifies the HTTP server. To connect to the `primeSequence` MCP server running on `http://localhost:9910`, specify the `primeSequence` MCP server endpoint:
```sh
python mcpstdio2http.py -url http://localhost:9910/primeSequence/mcp
```

Note that `mcpstdio2http.py` requires the `requests` Python package.
