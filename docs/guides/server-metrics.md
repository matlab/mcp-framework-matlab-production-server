# Server Metrics

Monitor your deployed MCP tools using the counters that the framework emits at runtime. You can check whether tools are being called, compare traffic across servers, and confirm a deployment is live.

## Introduction

MCP Framework metrics build on the [MATLAB Production Server metrics system](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html). MPS exposes server-level counters and gauges (requests accepted, failed, queued, CPU and memory usage) via a REST endpoint in Prometheus format. MCP Framework adds its own counters on top — tracking requests per MCP server and calls per tool — and exposes all of them through the `prodserver.mcp.metrics.Catalog` object in MATLAB.

Key points:

- Metrics are **MPS instance quantities** — they reflect the state of the entire server process, not a single archive or tool in isolation.
- All counters **reset to zero when MPS restarts.** There is no persistence across restarts.
- Metrics must be [enabled](#enabling-metrics-on-mps) in the MPS configuration (`--enable-metrics`). Without this, the server returns a 403 response.
- MPS also exposes built-in gauges (requests in queue, requests processing) that you can access through the same Catalog object alongside the MCP counters.
- Deployed MATLAB code can register custom counters and gauges using `prodserver.metrics.incrementCounter` and `prodserver.metrics.setGauge`. These appear in the Catalog labeled by their source archive.

## Contents

- [Quick check: is my tool being called?](#quick-check-is-my-tool-being-called)
- [Metric hierarchy](#metric-hierarchy)
- [Filtering metrics](#filtering-metrics)
- [Scoping by level](#scoping-by-level)
- [Enabling metrics on MPS](#enabling-metrics-on-mps)

---

## Quick Check: Is My Tool Being Called?

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/principalStress/mcp");
m = catalog.name("MCP_principalStress_Call");
fprintf("Tool called %d times\n", m.value)
```

If `m` is empty, the tool has not been called since the last server restart. If `prodserver.mcp.metrics` throws `prodserver:mcp:MetricsDisabled`, metrics are not enabled on the server — see [Enabling metrics on MPS](#enabling-metrics-on-mps).

---

## Metric Hierarchy

The framework emits three tiers of counters, from broadest to most specific:

| Metric | Name pattern | Increments when |
| :--- | :--- | :--- |
| Framework request | `MCP_Framework_Request` | Any request reaches any MCP handler on the instance |
| Server request | `MCP_<archive>_Request` | A request reaches the handler for a specific archive |
| Tool call | `MCP_<toolName>_Call` | A `tools/call` request invokes a specific tool |

All three are monotonically increasing counters. Values reset when MPS restarts.

### Example

Deploy an archive named `BeamAnalysis` containing a tool `analyzeBeam`, then call it twice:

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/BeamAnalysis/mcp");
catalog.name("MCP_Framework_Request").value     % 4 (2 calls + 2 metric queries)
catalog.name("MCP_BeamAnalysis_Request").value  % 2
catalog.name("MCP_analyzeBeam_Call").value      % 2
```

---

## Filtering Metrics

The catalog object supports filtering by name, archive, and type:

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/principalStress/mcp");

% Exact name match
catalog.name("MCP_Framework_Request")

% Substring match — find all metrics with "Request" in the name
catalog.name("Request", match="Contains")

% All metrics from one archive
catalog.archive("principalStress")

% Only counter metrics
catalog.type(prodserver.mcp.metrics.Type.Counter)

% Combine filters
catalog.filter(archive="principalStress", type=prodserver.mcp.metrics.Type.Counter)
```

Each filter method returns a struct array with fields: `name`, `type`, `archive`, `suffix`, and `value`.

---

## Scoping by Level

Use `scope()` to get metrics at a specific level of the hierarchy:

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/principalStress/mcp");

catalog.scope(prodserver.mcp.metrics.Scope.MCP)       % All MCP framework metrics
catalog.scope(prodserver.mcp.metrics.Scope.Server)    % Only this archive metrics
catalog.scope(prodserver.mcp.metrics.Scope.Instance)  % MPS instance metrics
```

| Scope | Returns |
| :--- | :--- |
| `All` | Every metric on the MPS instance |
| `Instance` | MPS instance metrics (prefix `matlabprodserver_`) |
| `MCP` | MCP framework metrics (prefix `MCP_`) |
| `Server` | Metrics matching the archive name from the endpoint URI |
| `Tool` | Metrics for the specific tool |

---

## Enabling Metrics on MPS

Metrics must be enabled on the MATLAB Production Server instance. Add this to your `main_config`:

```
--enable-metrics
```

Restart MPS after editing the configuration. Without this flag, `prodserver.mcp.metrics` throws an error.

---

See the [`metrics` reference](../reference/metrics.md) for the full Catalog API, including connection options (`timeout`, `retry`, `delay`).

--- Copyright 2026 The MathWorks, Inc. ---
