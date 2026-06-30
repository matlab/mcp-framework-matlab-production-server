# prodserver.mcp.metrics
```MATLAB
measurements = metrics(uri,scope)
```
Retrieve [metrics](https://www.mathworks.com/help/mps/restfuljson/restful-api-for-discovery-and-diagnostics.html#mw_205ec106-f8b5-4100-8845-da1db3a17dd3) from a MATLAB Production Server instance at `uri`. Returns a structure containing the metrics recorded by the server, filtered by `scope`. The `uri` may be either a MATLAB Production Server (MPS) address or an Model Context Protocol (MCP) tool endpoint; the server address is derived automatically.

Metrics must be enabled on the server. If metrics are disabled, the function throws an error with the identifier `prodserver:mcp:MetricsDisabled`.

### Inputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| uri | string | Server address or MCP tool endpoint. | "http://localhost:9910/primeSequence/mcp" |
| scope | MetricsScope | Filter reported metrics by scope. | prodserver.mcp.MetricsScope.MCP |

### Outputs
| Argument | Type | Description | Example
| :---     | :--- | :---        | :---    |
| measurements | struct | Structure with one field per metric. Each field value is a structure with fields `type`, `value` and `archive`. | measurements.MCP_Framework_Request.value |

### MetricsScope enumeration
| Value | Description |
| :---  | :---        |
| All | All metrics known to the MATLAB Production Server instance. |
| Instance | Only metrics starting with `matlabprodserver_`. |
| MCP | Only MCP framework metrics (starting with `MCP_`). This is the default. |
| Server | Only metrics containing the tool server (archive) name derived from the URI. |

### Optional Inputs (Name/Value pairs)
Pass optional arguments with *argument=value* syntax following required inputs. For example: `timeout=60`.
| Argument | Type | Description | Default |
| :---     | :--- | :---        | :---    |
| delay | integer | Number of seconds pause between retries | 2 |
| retry | integer | Number of times to retry on connection errors | 30 |
| timeout | integer | Number of seconds to wait for a reply | 180 |

### Output Structure

Each field in the returned `measurements` structure corresponds to a single metric. The field value is itself a structure with three fields:

| Field | Type | Description |
| :---  | :--- | :---        |
| type | string | The metric type as reported by the server (e.g., "counter" or "gauge"). |
| value | double or string | Numeric value for counter and gauge types; string otherwise. |
| archive | string | The archive (deployed CTF) that generated the metric. May be empty. |

# Examples

Retrieve all MCP-scoped metrics from a running server:
```MATLAB
m = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp")
```
Returns a structure with fields for each MCP metric. This call uses the default scope:  `MetricsScope.MCP`.

***

Retrieve metrics scoped to a specific MCP tool server:
```MATLAB
m = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp", ...
    prodserver.mcp.MetricsScope.Server)
```
Returns only those metrics whose names contain the MCP server name, which is derived from the endpoint URI -- `primeSequence`, in this example.

***

Check the total MCP framework request count:
```MATLAB
m = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp", ...
    prodserver.mcp.MetricsScope.MCP);
m.MCP_Framework_Request.value
```
The `value` field is a numeric count of requests handled by the MCP framework. This includes all requests to every MCP server hosted by the MPS instance at `localhost:9910` and all of the MCP tools hosted by those MCP servers.

***

Retrieve all metrics from the server instance with a shorter timeout:
```MATLAB
m = prodserver.mcp.metrics("http://localhost:9910/primeSequence/mcp", ...
    prodserver.mcp.MetricsScope.All, timeout=30, retry=5)
```
Returns every metric reported by the MATLAB Production Server, including both instance-level and MCP metrics.
