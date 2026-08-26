# Cheat Sheet

Quick reference for experienced users. All functions live in the `prodserver.mcp` namespace.

---

## Build and Deploy

```MATLAB
% Single tool — build and deploy in one step
[ctf, endpoint] = prodserver.mcp.build("myFunc", ...
    example=@() myFunc(input1, input2), ...
    server="http://localhost:9910");

% Multiple tools — single archive
[ctf, endpoint] = prodserver.mcp.build(["func1","func2","func3"], ...
    example={@() func1(a), @() func2(b), @() func3(c)}, ...
    archive="myServer", ...
    server="http://localhost:9910");

% Build only (deploy later)
ctf = prodserver.mcp.build("myFunc", example=@() myFunc(x));
endpoint = prodserver.mcp.deploy(ctf, "localhost", 9910);

% With resources
ctf = prodserver.mcp.build("myFunc", ...
    example=@() myFunc(x), ...
    resource=myResources, ...
    server="http://localhost:9910");

% Custom data marshaling wrapper
ctf = prodserver.mcp.build("myFunc", ...
    wrapper="myFuncMCP.m", ...
    server="http://localhost:9910");

% Force skip wrapper even for large parameters
ctf = prodserver.mcp.build("myFunc", ...
    wrapper="None", ...
    server="http://localhost:9910");

% Skip discovery registration
ctf = prodserver.mcp.build("myFunc", ...
    example=@() myFunc(x), ...
    discovery=false, ...
    server="http://localhost:9910");
```

---

## Verify and Test

```MATLAB
prodserver.mcp.ping(endpoint)                          % true if live
prodserver.mcp.call(endpoint, "myFunc", arg1, arg2)    % direct invocation
prodserver.mcp.list(endpoint, "Tool")                  % list tools
prodserver.mcp.list(endpoint, "Resource")              % list resources
prodserver.mcp.exist(endpoint, "myFunc", "tool")       % check specific tool
```

---

## Metrics

```MATLAB
catalog = prodserver.mcp.metrics(endpoint);

catalog.name("MCP_myFunc_Call")                         % tool call count
catalog.name("Request", match="Contains")              % substring search
catalog.archive("myServer")                            % all metrics from archive
catalog.type(prodserver.mcp.metrics.Type.Counter)      % counters only
catalog.scope(prodserver.mcp.metrics.Scope.MCP)        % framework metrics
catalog.filter(archive="myServer", type=prodserver.mcp.metrics.Type.Counter)
```

---

## Schema Generation

```MATLAB
% From example calls (most common)
ctf = prodserver.mcp.build("myFunc", example=@() myFunc(x, y));

% Multiple examples — different types or optional args
ctf = prodserver.mcp.build("myFunc", ...
    example={@() myFunc(x, y), @() myFunc(x, y, z)});

% Argument blocks alone (simple scalar types)
ctf = prodserver.mcp.build("myFunc");

% Pre-generate schema separately
defs = prodserver.mcp.schema("myFunc", @() myFunc(x, y));
ctf = prodserver.mcp.build("myFunc", definition=defs);
```

---

## Argument Block Patterns

```MATLAB
% Complete declaration — no example needed
function out = myFunc(a, b)
    arguments
        a (:,1) double  % Column vector of measurements
        b (1,1) string  % Analysis method
    end
    arguments (Output)
        out (1,1) double % Result
    end
end

% Comments only — relies on example for types
function out = myFunc(reading, channel)
    arguments
        reading  % Raw counts (uint16) or voltages (double)
        channel  % Sensor channel name
    end
end

% Structured input with %#schema
function out = myFunc(spec)
    arguments
        %#schema =spec_schema.json
        spec (1,1) struct  % Configuration specification
    end
end
```

---

## Client Configuration

```json
// Claude Code / Claude Desktop
{
  "mcpServers": {
    "myServer": {
      "url": "http://localhost:9910/myServer/mcp",
      "type": "http"
    }
  }
}
```

```json
// VS Code (settings.json)
{
  "mcp": {
    "servers": {
      "myServer": {
        "url": "http://localhost:9910/myServer/mcp",
        "type": "http"
      }
    }
  }
}
```

STDIO bridge (for clients without HTTP support):
```json
{
  "mcpServers": {
    "myServer": {
      "command": "python",
      "args": ["mcpstdio2http.py", "--url", "http://localhost:9910/myServer/mcp"]
    }
  }
}
```

---

## Resources

```MATLAB
% Define a resource
r = struct( ...
    'uri', 'mcp://data/material', ...
    'contents', 'aluminum.json', ...
    'description', 'Aluminum 6061-T6 properties', ...
    'mimeType', 'application/json');

% Multiple resources
resources = [aluminum, steel, titanium];

% Include in build
ctf = prodserver.mcp.build("myFunc", resource=resources, ...
    server="http://localhost:9910");
```

---

## AI Agent Skills

```MATLAB
prodserver.mcp.agent.setup    % register skill marketplace
```

Then in Claude Code: install plugin, `/reload-plugins`, use `/mps-mcp-build`.

---

## Key Build Options

| Option | Type | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `example` | handle or cell | `[]` | Example calls for schema generation |
| `server` | string | `""` | Deploy immediately to this address |
| `archive` | string | function name | CTF archive name |
| `resource` | struct array | `[]` | MCP resources to embed |
| `wrapper` | string | `"Auto"` | Wrapper mode: "Auto", "None", or path to custom wrapper |
| `discovery` | logical | `true` | Include in MPS discovery |
| `folder` | string | `"./deploy"` | Output directory for CTF |
| `files` | string vector | `""` | Extra files to include in archive |
| `timeout` | integer | `30` | Server interaction timeout (seconds) |
| `retry` | integer | `2` | Retry count for network operations |

---

## Endpoint URL Pattern

```
http://<host>:<port>/<archive>/mcp
```

Default archive name is the first function name. Override with the `archive` option.

--- Copyright 2026 The MathWorks, Inc. ---
