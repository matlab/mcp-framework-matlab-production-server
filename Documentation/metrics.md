# prodserver.mcp.metrics
```MATLAB
catalog = metrics(uri)
```
Retrieve [metrics](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html#mw_205ec106-f8b5-4100-8845-da1db3a17dd3) from a MATLAB Production Server instance at `uri`. Returns a `prodserver.mcp.metrics.Catalog` object that provides methods for filtering and querying the metrics recorded by the server. The `uri` may be either a MATLAB Production Server (MPS) address or a Model Context Protocol (MCP) tool endpoint; the server address is derived automatically.

Metrics must be enabled on the server. If metrics are disabled, the function throws an error with the identifier `prodserver:mcp:MetricsDisabled`.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| uri | string | Server address or MCP tool endpoint. | "http://localhost:9910/primeSequence/mcp" |

### Outputs
| Argument | Type | Description |
| :---     | :--- | :---        |
| catalog | prodserver.mcp.metrics.Catalog | Catalog object with methods for filtering metrics by name, archive, type, and scope. |

### Optional Inputs (Name/Value pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=60`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds pause between retries | 2 |
| retry | integer | Number of times to retry on connection errors | 30 |
| timeout | integer | Number of seconds to wait for a reply | 180 |

## Catalog API

The returned `Catalog` object provides the following filter methods. Each method returns a struct array with fields `name`, `type`, `archive`, and `value`.

### Filter Methods

| Method | Signature | Description |
| :---   | :---      | :---        |
| name | `m = catalog.name(n)` | All metrics with name exactly matching `n` |
| name | `m = catalog.name(n, match="Contains")` | All metrics whose name contains `n` |
| archive | `m = catalog.archive(a)` | All metrics from archive `a` exactly |
| archive | `m = catalog.archive(a, match="Contains")` | All metrics from archives containing `a` |
| type | `m = catalog.type(t)` | All metrics of type `t` |
| scope | `m = catalog.scope(s)` | All metrics matching scope `s` |

### Return Value

Each filter method returns a struct array. Each element has four fields:

| Field | Type | Description |
| :---  | :--- | :---        |
| name | string | The metric name (e.g., "MCP_Framework_Request"). |
| type | string | The metric type ("counter" or "gauge"). |
| archive | string | The archive (deployed CTF) that generated the metric. Empty for instance-level metrics. |
| value | double or string | Numeric value for counter and gauge types; string otherwise. |

A metric name may appear multiple times when the same metric is reported by different archives.

### Enumerations

#### prodserver.mcp.metrics.Scope
| Value | Description |
| :---  | :---        |
| All | All metrics known to the MATLAB Production Server instance. |
| Instance | Only MPS instance metrics (prefix `matlabprodserver_`). |
| MCP | Only MCP framework metrics (prefix `MCP_`). |
| Server | Only metrics matching the archive name derived from the URI. |
| Tool | Only metrics for the specific tool. |

#### prodserver.mcp.metrics.Type
| Value | Description |
| :---  | :---        |
| Counter | Monotonically increasing counters. Reset on server restart. |
| Gauge | Point-in-time measurements that can increase or decrease. |

#### prodserver.mcp.metrics.Match
| Value | Description |
| :---  | :---        |
| Exact | Exact string match (default). |
| Contains | Substring match. |

# Examples

Retrieve a metrics catalog from a running server:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp")
```
Returns a Catalog object. Use filter methods to query specific metrics.

***

Get all MCP-scoped metrics:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.scope(prodserver.mcp.metrics.Scope.MCP)
```
Returns a struct array of all metrics with the `MCP_` prefix.

***

Check the total MCP framework request count:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.name("MCP_Framework_Request");
m(1).value
```
The `value` field is a numeric count of requests handled by the MCP framework across all archives on the instance.

***

Get all metrics from a specific archive:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.archive("primeSequence")
```
Returns all metrics reported by the `primeSequence` archive.

***

Filter by type:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.type(prodserver.mcp.metrics.Type.Counter)
```
Returns only counter metrics.

***

Substring matching on metric names:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp");
m = catalog.name("Request", match="Contains")
```
Returns all metrics whose name contains "Request".

***

Retrieve metrics with a shorter timeout:
```MATLAB
catalog = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp", ...
    timeout=30, retry=5)
```
Returns a Catalog for every metric reported by the MATLAB Production Server.


--- Copyright 2025-2026 The MathWorks, Inc. ---
