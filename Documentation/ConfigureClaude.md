# Calling MCP Tools from Claude

## Two Types of MCP Servers

## File System Access


# Periodic Noise Example

Assumptions:
* Python is available on your system path as the command "python".
* The MCP Framwork (this repo) installed in a folder named /work.
* Log files should be written to `/work/logs/mcp/claude`.
* The MATLAB Production Server hosting the MCP tools has the network address "http://localhost:9910".
Modify the configuration file as necessary for your environment.

```json
{
  "mcpServers": {
    "cleanSignal": {
      "command": "python",
      "args": [
	    "/work/mcp-framework-matlab-production-server/Utilities/mcpstdio2http.py", 
		"--log-level", "DEBUG",
		"--log-dir", "/work/logs/mcp/claude",
        "--url", "http://localhost:9910/cleanSignal/mcp",
		"--timeout", "300"
      ],
	  "networkTimeout": 600
    },
	"linePlot": {
      "command": "python",
      "args": [
	    "/work/mcp-framework-matlab-production-server/Utilities/linePlot.py", 
		"--log-level", "DEBUG",
		"--log-dir", ""/work/logs/mcp/claude"",
		"--timeout", "300"
      ],
	  "networkTimeout": 600
    }
  }
}
```