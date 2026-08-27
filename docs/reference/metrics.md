# prodserver.mcp.metrics
```MATLAB
catalog = metrics(uri)
```
Retrieve [metrics](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html#mw_205ec106-f8b5-4100-8845-da1db3a17dd3) from a MATLAB Production Server instance at `uri`. The function returns a `prodserver.mcp.metrics.Catalog` object that provides methods for filtering and querying the metrics recorded by the server. The `uri` may be either a MATLAB Production Server (MPS) address or a Model Context Protocol (MCP) tool endpoint; the function derives the server address automatically.

Metrics must be enabled on the server. If metrics are disabled, the function throws an error with the identifier `prodserver:mcp:MetricsDisabled`.

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
| retry | integer | Number of times to retry on connection errors | 30 |
| timeout | integer | Number of seconds to wait for a reply | 180 |

## Catalog API

The returned `Catalog` object provides filter methods for querying metrics. Each method returns a struct array with fields `name`, `type`, `archive`, `suffix`, and `value`.

### Filter Methods

| Method | Signature | Description |
| :---   | :---      | :---        |
| archive | `m = catalog.archive(a, match=m)` | Metrics from archive `a`. `match` is optional.  |
| filter | `m = catalog.filter(name=n, archive=a, type=t, match=m)` | Combined filter — all arguments are optional |
| name | `m = catalog.name(n, match=m)` | Metrics matching name `n`. `match` is optional. |
| scope | `m = catalog.scope(s)` | Metrics matching scope `s` (`prodserver.mcp.metrics.Scope`) |
| type | `m = catalog.type(t)` | Metrics of type `t` (`prodserver.mcp.metrics.Type`) |

The `filter` method accepts any combination of `name`, `archive`, `type`, and `match` as name-value arguments. Omitted criteria are not applied. The `name` and `archive` methods are convenience wrappers that accept the same `match` argument.

### The `match` Argument

The `name`, `archive`, and `filter` methods accept an optional `match` argument of type `prodserver.mcp.metrics.Match`.

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

### The `scope` Argument

Pass a `prodserver.mcp.metrics.Scope` enumeration to `catalog.scope()`.

| Value | Returns |
| :--- | :--- |
| `Scope.All` | Every metric on the MPS instance |
| `Scope.Instance` | MPS instance metrics (prefix `matlabprodserver_`) |
| `Scope.MCP` | MCP framework metrics (prefix `MCP_`) |
| `Scope.Server` | Metrics matching the archive name from the endpoint URI |
| `Scope.Tool` | Metrics for the specific tool |

### Return Value

Each filter method returns a struct array with five fields per element.

| Field | Type | Description |
| :---  | :--- | :---        |
| name | string | The metric name (e.g., "MCP_Framework_Request"). |
| type | string | The metric type ("counter" or "gauge"). |
| archive | string | The archive (deployed CTF) that generated the metric. Empty for instance-level metrics. |
| suffix | string or [] | The numeric deployment suffix (e.g., "3" from "AlphaServer_3"). Empty for instance-level metrics. |
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
The method returns a struct array of all metrics with the `MCP_` prefix.

***

Check the total MCP framework request count.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.name("MCP_Framework_Request");
m(1).value
```
The `value` field is a numeric count of requests handled by the MCP framework across all archives on the instance.

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

Retrieve metrics with a shorter timeout.
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp", ...
    timeout=30, retry=5)
```
The function returns a Catalog for every metric reported by the MATLAB Production Server.


--- Copyright 2025-2026 The MathWorks, Inc. ---
