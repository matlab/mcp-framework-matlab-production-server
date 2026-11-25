# prodserver.mcp.metrics
```MATLAB
catalog = metrics(uri)
```
Retrieve [metrics](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html#mw_205ec106-f8b5-4100-8845-da1db3a17dd3) from a MATLAB Production Server instance at `uri`. The function returns a `prodserver.mcp.metrics.Catalog` object that provides methods for filtering and querying the metrics recorded by the server. The `uri` may be either a MATLAB Production Server (MPS) address or a Model Context Protocol (MCP) tool endpoint; the function derives the server address automatically.

Metrics must be enabled on the server. If metrics are disabled, the function throws an error with the identifier `prodserver:mcp:MetricsDisabled`.

The framework's counts are best effort. If the server can't write one, the MCP request still succeeds, the count is lost, and the archive logs a `prodserver:mcp:MetricWriteFailed` warning, at most once a minute for each metric. A counter can then be lower than the number of requests it counts.

The catalog always holds every metric on the instance, whichever form `uri` takes. An MCP endpoint also names an archive, which the catalog's display shows; to select that archive's metrics, use `catalog.archive` or `catalog.filter(archive=...)`. The function first checks that the server has that archive, through the archive's `/ping` route, which counts nothing. Production Server answers 404 alike for an archive it doesn't have and one it is still deploying, so the function waits out a 404 as [`call`](./call.md#an-archive-that-answers-404) does, `retry` times `delay` seconds apart, warning that it is waiting. If the archive still doesn't answer, the function throws `prodserver:mcp:UnknownArchive`, rather than returning the instance's metrics as though they were the archive's. A server address, with or without a trailing slash, names no archive and isn't checked. A refused connection is resent once. A timeout on the archive check is resent once too, but a timeout on `/api/metrics` isn't: the timeout is long, and a server that took that long would likely take as long again. If the server still doesn't answer, the function throws `prodserver:mcp:ServerUnresponsive`. For `/api/metrics`, the message says whether the connection was refused or timed out. Any other failure of `/api/metrics`, such as an HTTP status or a host that can't be found, raises MATLAB's error, with its identifier, such as `MATLAB:webservices:HTTP504StatusCodeError`; a 504 Gateway Timeout or a 408 Request Timeout is the server's answer, not a timeout. No message shows user information or a query from the address.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| uri | string | Server address or MCP tool endpoint. | "http://localhost:9910/primeSequence/mcp" |

### Outputs
| Argument | Type | Description |
| :---     | :--- | :---        |
| catalog | prodserver.mcp.metrics.Catalog | Catalog object with methods for filtering metrics by name, archive, type, and scope. |

### Optional Inputs (Name/Value Pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=60`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds to pause between retries | 2 |
| retry | integer | Number of times to resend the archive check after Production Server's 404, for an archive it doesn't have or is still deploying. A refused connection is resent once, whatever `retry` is. So is a timeout on the archive check, but not one on `/api/metrics`. | 30 |
| timeout | integer | Number of seconds to wait for a reply | 180 |

## Catalog API

A catalog is a snapshot of every metric the server reported when `metrics` was called; call `metrics` again to update it. Displayed, it summarises what it holds:

```
>> catalog = prodserver.mcp.metrics("http://localhost:9910/WireEncoding/mcp")
catalog = 

  Catalog of 90 metrics from MATLAB Production Server http://localhost:9910, for archive WireEncoding:

    10 instance (matlabprodserver_*)    80 MCP framework (MCP_*)
    5 tool(s) called: analyzeACCircuit 2, blendImages 1, matrixMultiply 3, read_mcp_resource 1, ...

  Query it with name, archive, type, filter or scope, for example catalog.name("MCP_Framework_Request").
  A snapshot: call prodserver.mcp.metrics again to update it.
```

The tool line counts each tool's `MCP_<tool>_Call` calls, summed over the archives that report them, and lists the first few tools by name. A catalog with no metrics says so. The summary never shows user information from the address, such as a password.

The returned `Catalog` object provides filter methods for querying metrics. Each method returns a struct array with fields `name`, `type`, `archive`, `suffix`, and `value`.

### Filter Methods

| Method | Signature | Description |
| :---   | :---      | :---        |
| archive | `m = catalog.archive(a, match=m, suffix=s)` | Metrics from archive `a`. `match` and `suffix` are optional.  |
| filter | `m = catalog.filter(scope=s, name=n, archive=a, type=t, match=m, suffix=s)` | Combined filter — all arguments are optional |
| name | `m = catalog.name(n, match=m)` | Metrics matching name `n`. `match` is optional. |
| scope | `m = catalog.scope(s)` | Metrics of kind `s` (`prodserver.mcp.metrics.Scope`), from every archive |
| type | `m = catalog.type(t)` | Metrics of type `t` (`prodserver.mcp.metrics.Type`) |

The `filter` method accepts any combination of `scope`, `name`, `archive`, `type`, `match`, and `suffix` as name-value arguments. Omitted criteria are not applied. The `name`, `archive`, `scope` and `type` methods are convenience wrappers for `filter` with one criterion. The `name` and `archive` methods accept the same `match` argument, and `archive` also accepts `suffix`.

### The `match` Argument

The `name`, `archive`, and `filter` methods accept an optional `match` argument of type `prodserver.mcp.metrics.Match`. It applies to `name` and `archive`, not to `scope`.

| Value | Behavior |
| :--- | :--- |
| `Match.Exact` | Exact string comparison (default) |
| `Match.Contains` | Substring match |

```MATLAB
catalog.name("Request", match=prodserver.mcp.metrics.Match.Contains)
catalog.archive("Beam", match="Contains")   % string shorthand also accepted
```

### The `type` Argument

Pass a `prodserver.mcp.metrics.Type` enumeration to `catalog.type()` or `catalog.filter(type=...)`.

| Value | Description |
| :--- | :--- |
| `Type.Any` | Do not filter by type (default for `filter`) |
| `Type.Counter` | Monotonically increasing counters. Reset on server restart. |
| `Type.Gauge` | Point-in-time measurements that can increase or decrease. |

### The `suffix` Argument

MATLAB Production Server reports an archive's metrics under the name of its deployed folder: the archive name and a number it adds, such as `AlphaServer_3`. The Catalog reports the base name in `archive` and the number, as a string such as `"3"`, in `suffix`. Use the `suffix` argument of `filter` or `archive` to select metrics by deployment.

| Value | Selects |
| :--- | :--- |
| Number or numeric array, such as `3` or `[3 5]` | Metrics whose suffix is one of the values |
| Text that converts to a number, such as `"3"` | The same as the number |
| `NaN` | Metrics with no suffix: instance-level metrics, and archives reported without a number |
| Function handle | The function receives the suffixes of the metrics that match the other criteria, as a numeric array with `NaN` for no suffix. It returns either suffix values to select, as with `@max`, or a logical mask of the same size as its input, as with `@(s) s > 3`. |

The suffix filter is applied after the other criteria, so `suffix=@max` selects the most recent deployment among the metrics that match `name`, `archive`, and `type`. If none of those metrics has a suffix, `@max` returns `NaN` and selects all of them.

### The `scope` Argument

A scope is a kind of metric. Pass a `prodserver.mcp.metrics.Scope` enumeration to `catalog.scope()` or `catalog.filter(scope=...)`. The kind is read from the metric's name, so each scope covers every archive on the instance, whatever archive `uri` names. To select one archive's metrics of a kind, add `archive`: `catalog.filter(scope=prodserver.mcp.metrics.Scope.Tool, archive="primeSequence")`.

`All` is `Instance`, `MCP` and `Custom`, and `MCP` is `Framework`, `Server` and `Tool`. No metric is of two kinds at the same level.

| Value | Returns |
| :--- | :--- |
| `Scope.All` | Every metric on the MPS instance |
| `Scope.Instance` | MPS instance metrics (prefix `matlabprodserver_`) |
| `Scope.MCP` | The MCP framework's metrics: those of `Framework`, `Server` and `Tool` |
| `Scope.Framework` | `MCP_Framework_Request`, one per archive |
| `Scope.Server` | Each archive's `MCP_<archive>_Request` and `MCP_<archive>_ElapsedTime`. The name must match the metric's own `archive`, so archive `foo` reports no `MCP_foo_bar_Request`. |
| `Scope.Tool` | Each tool's `MCP_<tool>_Call`, `MCP_<tool>_Rejected` and `MCP_<tool>_Refused`, and their per-revision counters, such as `MCP_<tool>_Call_2026_07_28`. Each call counts in both `MCP_<tool>_Call` and its per-revision counter, so don't sum the two. To select one tool, use `catalog.name("MCP_<tool>_Call")`. |
| `Scope.Custom` | The metrics deployed code reports itself, with `prodserver.metrics.incrementCounter` or `setGauge`: those of no other kind, including any whose name starts `MCP_` |

### Return Value

Each filter method returns a struct array with five fields per element.

| Field | Type | Description |
| :---  | :--- | :---        |
| name | string | The metric name (e.g., "MCP_Framework_Request"). |
| type | string | The metric type ("counter" or "gauge"). |
| archive | string | The archive (deployed CTF) that generated the metric. Empty for instance-level metrics. |
| suffix | string or [] | The numeric deployment suffix (e.g., "3" from "AlphaServer_3"). Empty for instance-level metrics and for archives reported without a suffix. |
| value | double or string | Numeric value for counter and gauge types; string otherwise. |

A metric name may appear multiple times when the same metric is reported by different archives.

# Examples

Retrieve a metrics catalog from a running server.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp")
```
The function returns a Catalog object. Use filter methods to query specific metrics.

***

Get all MCP-scoped metrics.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.scope(prodserver.mcp.metrics.Scope.MCP)
```
The method returns a struct array of the MCP framework's metrics, from every archive on the instance.

***

Get one archive's tool counters.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.filter(scope=prodserver.mcp.metrics.Scope.Tool, archive="primeSequence")
```
The method returns the call, rejection and per-revision counters of the tools in `primeSequence`, and no other archive's.

***

Check the total MCP framework request count.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.name("MCP_Framework_Request");
sum([m.value])
```
MPS labels `MCP_Framework_Request` with the archive that counted it, so the catalog has one element per archive, each with that archive's count in `value`. Their sum is the number of requests the MCP framework has handled across all archives on the instance. For one archive's count, select it: `catalog.filter(name="MCP_Framework_Request", archive="primeSequence")`.

***

Get all metrics from a specific archive.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.archive("primeSequence")
```
The method returns all metrics reported by the `primeSequence` archive.

***

Filter by type.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.type(prodserver.mcp.metrics.Type.Counter)
```
The method returns only counter metrics.

***

Substring matching on metric names.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.name("Request", match="Contains")
```
The method returns all metrics whose name contains "Request".

***

Combined filtering with the `filter` method.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.filter(archive="primeSequence", type=prodserver.mcp.metrics.Type.Counter)
```
The method returns only counter metrics from the `primeSequence` archive.

***

Get the metrics of the most recent deployment of an archive.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.archive("primeSequence", suffix=@max)
```
The method returns the metrics of the `primeSequence` deployment with the largest suffix. If `primeSequence` was deployed only once, and so has no suffix, it returns all of that archive's metrics.

***

Retrieve metrics with a shorter timeout.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp", ...
    timeout=30, retry=5)
```
The function returns a Catalog for every metric reported by the MATLAB Production Server.


--- Copyright 2025-2026 The MathWorks, Inc. ---
