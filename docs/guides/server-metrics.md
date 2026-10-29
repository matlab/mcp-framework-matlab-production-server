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
  - [Several deployments of one archive](#several-deployments-of-one-archive)
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
| Framework request | `MCP_Framework_Request` | A `POST` or `DELETE` reaches any archive's `/<archive>/mcp`. MPS labels the counter with the archive, so the catalog has one per archive. |
| Server request | `MCP_<archive>_Request` | A `POST` or `DELETE` reaches `/<archive>/mcp` |
| Tool call | `MCP_<toolName>_Call` | A `tools/call` request invokes a specific tool |

All three are monotonically increasing counters. Values reset when MPS restarts.

Three more counters break tool calls down, and one totals the time requests take:

| Metric | Name pattern | Increments when |
| :--- | :--- | :--- |
| Tool call by revision | `MCP_<toolName>_Call_<revision>` | A `tools/call` request invokes the tool under that protocol revision. The revision's hyphens become underscores: `MCP_principalStress_Call_2025_06_18`, `MCP_principalStress_Call_2026_07_28`. |
| Rejected tool call | `MCP_<toolName>_Rejected` | The server refuses a `tools/call` request for the tool before invoking it |
| Rejected tool call by revision | `MCP_<toolName>_Rejected_<revision>` | The same, under that protocol revision |
| Server elapsed time | `MCP_<archive>_ElapsedTime` | A request to `/<archive>/mcp` finishes. The counter adds the seconds the request took, including the tool's run time, so it holds the total. Divide it by `MCP_<archive>_Request` for the average. |

A tool call is counted when the tool is invoked, whether or not the tool then raises an error. A call the server refuses before invoking the tool is counted as rejected instead: one with a missing, unknown or invalid argument, or with arguments it can't decode. See [Tool Arguments](../concepts/protocol-conformance.md#tool-arguments). So each request that names one of the archive's tools counts once, in either `_Call` or `_Rejected`. A request naming a tool the archive doesn't have counts in neither.

Rejections show how often a model calls a tool wrongly. A tool with many is a sign that its parameter descriptions or schema need work.

### Example

Deploy an archive named `BeamAnalysis` containing a tool `analyzeBeam`, then call it twice with `prodserver.mcp.call` from a new MATLAB session:

```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/BeamAnalysis/mcp");
catalog.name("MCP_BeamAnalysis_Request").value  % 5
catalog.name("MCP_analyzeBeam_Call").value      % 2
```

A `call` makes more than one request. Each call sends `tools/list` and `tools/call`, and the first also sends `server/discover` to pick the protocol revision, which `call` then remembers. Against a server that doesn't answer `server/discover`, such as one built with release 1.5, each call also opens and closes a `2025-06-18` session. The `signature` request that `call` sends, `ping`, and metric queries aren't counted.

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

### Several Deployments of One Archive

Deploying an archive again under the same name can leave metrics from each deployment on the server, reported under numbered names such as `principalStress_2`. The Catalog reports them all with `archive` set to `principalStress` and the number in `suffix`. To see only the most recent deployment, select the largest suffix:

```MATLAB
catalog.archive("principalStress", suffix=@max)
```

`suffix` also accepts specific numbers, `NaN` for metrics with no suffix, and a function that returns a logical mask. See [`metrics`](../reference/metrics.md#the-suffix-argument).

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
| `Tool` | The `MCP_<tool>_Call` counter of every tool on the instance |

---

## Enabling Metrics on MPS

Metrics must be enabled on the MATLAB Production Server instance. Uncomment this in your `main_config`:

```
--enable-metrics
```

Restart MATLAB Production Server after editing the configuration. Without this flag, `prodserver.mcp.metrics` throws an error.

---

See the [`metrics` reference](../reference/metrics.md) for the full Catalog API, including connection options (`timeout`, `retry`, `delay`).

--- Copyright 2026 The MathWorks, Inc. ---
