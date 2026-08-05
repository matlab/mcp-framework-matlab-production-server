# MCP Resources

MCP Resources expose read-only data from your server. An LLM can discover and read resources to obtain context before calling tools. Resources are identified by URIs and contain text or binary content. Include resources in your servers via the `build` command:

```MATLAB
ctf = prodserver.mcp.build(fcn, resource=resources)
```

## When to Use Resources

Use resources when your tools require reference data that the LLM should not hallucinate. Common examples:

| Domain | Resource Content | Paired Tool |
| :--- | :--- | :--- |
| Structural analysis | Material properties (modulus, yield strength) | Stress/deflection calculator |
| Signal processing | Sensor calibration coefficients | Measurement conversion |
| Control systems | PID tuning parameters, plant models | Simulation runner |
| Data analysis | Dataset schemas, variable descriptions | Query or analysis functions |

**Resources provide the data that makes tools usable without requiring the user to supply domain knowledge**.

## Defining Resources

A resource is a MATLAB structure with at least two fields: `uri` and `contents`. Optional fields provide information that allows an LLM to interact with the resource more effectively.

```MATLAB
resource = struct( ...
    'uri', 'mcp://materials/aluminum_6061', ...
    'contents', 'aluminum_6061.json', ...
    'name', 'aluminum_6061', ...
    'title', 'Aluminum 6061-T6', ...
    'description', 'Mechanical and thermal properties of Aluminum 6061-T6.', ...
    'mimeType', 'application/json');
```

### Required Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| uri | string | Unique URI identifying the resource. Any valid URI scheme. |
| contents | string | Literal text content, or a file path containing the content. |

* The `uri` is a server-specific key or label by which the resource is known to the LLM. If there are multiple resources, each must have a `uri` unique within **the server**. Multiple servers may have identically named `uri`s, as the resource read always occurs within the context of a given server.

* If `contents` is a file path, `build` will fetch the contents of the file in its entirety and include that data in the deployable archive.

### Optional Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| name | string | Machine-readable name. Auto-generated from filename if omitted. |
| title | string | Human-readable display title. |
| description | string | Description of the resource. Helps the LLM decide whether to read it. |
| mimeType | string | MIME type of the content. Defaults to `text/plain` for text content. |

### Content Sources

The `contents` field accepts either literal text or a path to a file:

```MATLAB
% Literal content
r1 = struct('uri', 'mcp://data/greeting', ...
    'contents', 'Hello, world!');

% File-based content (file read at build time)
r2 = struct('uri', 'mcp://data/config', ...
    'contents', '/path/to/config.json', ...
    'mimeType', 'application/json');
```

When `contents` is a file path, the file is read during `prodserver.mcp.build` and its content is embedded in the server. Binary files (non-text MIME types) are stored as byte arrays.

## Passing Resources to build

Pass resources to `prodserver.mcp.build` using the `resource` name-value argument. Resources may be a single struct or a struct array:

```MATLAB
% Single resource
ctf = prodserver.mcp.build("myTool", resource=myResource);

% Multiple resources as a struct array
resources = [catalog, material1, material2];
ctf = prodserver.mcp.build("myTool", resource=resources);
```

## Built-in Resources

Every MCP server automatically includes a wire-encoding resource at `mcp://protocol/tools/wire-format/parameters/encoding_rules`. This resource documents how tool parameters are encoded over the wire. You do not need to define it; it is always present.

## Accessing Resources

### From an MCP Client

MCP clients discover resources via the `resources/list` protocol method and read them via `resources/read`. Use `prodserver.mcp.list` to query resources from MATLAB:

```MATLAB
resources = prodserver.mcp.list(endpoint, "resource")
```

### From an LLM (via built-in tool)

Some MCP clients do not yet support direct resource access. Every server built with MCP Framework includes a built-in tool called `read_mcp_resource` that allows the LLM to read any resource by URI:

```
Tool: read_mcp_resource
Input: {"uri": "mcp://materials/aluminum_6061"}
```

This ensures resources are accessible regardless of client capabilities.

## URI Schemes

Resource URIs may use any scheme. Choose a scheme that conveys the resource's domain:

| Scheme | Use Case | Example |
| :--- | :--- | :--- |
| `mcp://` | General MCP resources | `mcp://materials/steel_304` |
| `data://` | Dataset references | `data://sensors/channel_3` |
| `config://` | Configuration data | `config://filter/butterworth` |

The URI must be unique within a server. The scheme is for human and LLM readability only -- MCP Framework does not interpret or route based on scheme.

## Design Guidelines

1. **Include a catalog resource** that lists all other resources with brief descriptions. This helps the LLM discover what data is available.

2. **Write clear descriptions** for each resource. The LLM uses descriptions to decide which resources to read.

3. **Use JSON for structured data**. Set `mimeType` to `application/json`. JSON is universally parseable by LLMs.

4. **Include units in property values**. Engineering data without units is ambiguous. Structure properties as `{"value": 68.9e9, "units": "Pa"}`.

5. **Keep resources focused**. One material per resource is better than all materials in one resource. The LLM reads only what it needs.

## Example

See the [Materials](../Examples/Materials/Materials.md) example for a complete demonstration: a materials engineering server with property resources and structural/thermal analysis tools.

--- Copyright 2026 The MathWorks, Inc. ---
