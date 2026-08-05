# Observability

This document describes how to monitor MCP Framework tools deployed on MATLAB Production Server (MPS). Observability is provided through counter-based metrics emitted by the framework at runtime and queryable via `prodserver.mcp.metrics`.

## Metric Hierarchy

The MCP Framework emits three tiers of counters, from broadest to most specific:

| Metric | Name Pattern | Incremented When |
| :--- | :--- | :--- |
| Framework request | `MCP_Framework_Request` | Any request reaches any MCP handler on the instance |
| Server request | `MCP_<archive>_Request` | A request reaches the MCP handler for a specific archive (tool server) |
| Tool call | `MCP_<toolName>_Call` | A `tools/call` request invokes a specific tool |

All three are counters (monotonically increasing). Values reset when the MPS instance restarts.

### Example

After deploying an archive named `BeamAnalysis` containing a tool `analyzeBeam` and calling it twice:

```
MCP_Framework_Request     = 4   (2 calls + 2 metric queries)
MCP_BeamAnalysis_Request  = 2
MCP_analyzeBeam_Call      = 2
```

## Querying Metrics

Use `prodserver.mcp.metrics` to retrieve a metrics catalog from a running MPS instance:

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/BeamAnalysis/mcp");
catalog.name("MCP_Framework_Request").value      % Total framework requests
catalog.name("MCP_BeamAnalysis_Request").value   % Requests to this server
catalog.name("MCP_analyzeBeam_Call").value       % Calls to this tool
```

See [metrics.md](metrics.md) for the full function reference including filter methods and options.

## Scopes

The `prodserver.mcp.metrics.Scope` enumeration controls which metrics are returned when filtering with the `scope()` method:

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/BeamAnalysis/mcp");
m = catalog.scope(prodserver.mcp.metrics.Scope.Instance);
```

| Scope | Returns |
| :--- | :--- |
| `All` | Every metric on the MPS instance (MCP + instance-level) |
| `Instance` | Only MPS instance metrics (prefix `matlabprodserver_`) |
| `MCP` | Only MCP framework metrics (prefix `MCP_`) |
| `Server` | Only metrics matching the archive name from the endpoint URI |
| `Tool` | Only metrics for the specific tool |

## Filtering

The metrics catalog also supports filtering by `name`, `archive`, and `type`. Both exact and substring matching are available via the `match` option:

```MATLAB
catalog.name("Request", match="Contains")       % All metrics with "Request" in name
catalog.archive("BeamAnalysis")                  % All metrics from one archive
catalog.type(prodserver.mcp.metrics.Type.Counter) % All counter metrics
```

The `filter` method combines multiple criteria in a single call:

```MATLAB
catalog.filter(archive="BeamAnalysis", type=prodserver.mcp.metrics.Type.Counter)
```

See [metrics.md](metrics.md) for the complete Catalog API reference.

## Enabling Metrics

Metrics must be enabled on the MPS instance. Add the following to `main_config`:

```
--enable-metrics
```

If metrics are disabled, `prodserver.mcp.metrics` throws `prodserver:mcp:MetricsDisabled`.

## Transport Proxy Logging

The `mcpstdio2http` transport bridge (used to connect stdio-based MCP hosts to the HTTP-based MPS) supports file-based logging:

```
python mcpstdio2http.py --server http://localhost:9910/myTool/mcp \
    --log-file ./mcp_bridge.log --log-level DEBUG
```

This logs every JSON-RPC message flowing through the bridge. See [mcpstdio2http.md](mcpstdio2http.md) for details.

The `linePlot` visualization proxy also supports the same logging options. See [linePlot.md](linePlot.md).

## MPS Server Logs

MATLAB Production Server writes its own operational logs (worker lifecycle, HTTP errors, deployment events). These are configured via the MPS `main_config` file and are outside the scope of the MCP Framework. Consult the [MPS documentation](https://www.mathworks.com/help/mps/server/use-log-files.html) for details.

--- Copyright 2026 The MathWorks, Inc. ---
