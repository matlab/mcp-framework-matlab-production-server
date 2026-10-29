# MCP Resources

Serve read-only reference data alongside your tools. Resources give the LLM access to real values — material properties, calibration coefficients, configuration tables — so it does not have to guess or ask the user.

[Resources](https://modelcontextprotocol.io/docs/concepts/resources) are an official part of the Model Context Protocol. They provide a standard way for MCP servers to expose data that clients can discover and read. Unlike tools (which perform computation), resources are purely informational — an LLM reads them for context before deciding what to do. MCP Framework lets you attach resources to any server you build, embedding the data in the deployed archive.

## Contents

- [When to use resources](#when-to-use-resources)
- [Define a resource](#define-a-resource)
- [Include resources in a build](#include-resources-in-a-build)
- [How the LLM accesses resources](#how-the-llm-accesses-resources)
- [Design guidelines](#design-guidelines)
- [Complete example](#complete-example)

---

## When to Use Resources

Use resources when your tools need reference data that the LLM should not hallucinate:

| Domain | Resource content | Paired tool |
| :--- | :--- | :--- |
| Structural analysis | Material properties (modulus, yield strength) | Stress calculator |
| Signal processing | Sensor calibration coefficients | Measurement conversion |
| Control systems | PID tuning parameters | Simulation runner |
| Data analysis | Dataset schemas, variable descriptions | Query functions |

Resources provide the data that makes tools usable without requiring the user to supply domain knowledge.

---

## Define a Resource

A resource is a struct with a `uri` and `contents`. Optional fields help the LLM decide whether to read it.

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
| `uri` | string | Unique identifier for the resource within this server |
| `contents` | string or uint8 | Literal text, raw bytes (uint8) for binary content, or a path to a file containing the content |

If `contents` is a file path, `build` reads the file and embeds its content in the archive. The file is read once at build time. A file with a text `mimeType` (`text/*`, `application/json` and similar), or with no `mimeType`, is read as UTF-8 text; with no `mimeType` it is labelled `text/plain`. A file with any other `mimeType` is read as bytes.

The server Base64-encodes binary content when it sends it, as MCP requires, so give binary content as raw `uint8` bytes. Don't Base64-encode it yourself: it would be encoded twice.

### Optional Fields

| Field | Type | Description |
| :--- | :--- | :--- |
| `name` | string | Machine-readable name. If omitted: for a file, the file name with its extension appended without the dot (`aluminum_6061.json` gives `aluminum_6061json`); for a function handle, the function's name; for literal contents, `resourceN`, where N is the resource's position in the list. |
| `title` | string | Human-readable display title |
| `description` | string | Helps the LLM decide whether to read this resource |
| `mimeType` | string | MIME type of the content. Defaults to `text/plain` for text and `application/octet-stream` for raw bytes (`uint8`). An empty `mimeType` (`''`) means the default. |

### Content Sources

```MATLAB
% Literal string content
r1 = struct('uri', 'mcp://data/greeting', ...
    'contents', 'Hello, world!');

% File-based content (read at build time)
r2 = struct('uri', 'mcp://data/config', ...
    'contents', 'config.json', ...
    'mimeType', 'application/json');
```

---

## Include Resources in a Build

Pass a struct or struct array to `prodserver.mcp.build` via the `resource` argument:

```MATLAB
% Single resource
ctf = prodserver.mcp.build("thermalAnalysis", resource=material);

% Multiple resources
materials = [aluminum, steel, titanium];
ctf = prodserver.mcp.build("thermalAnalysis", resource=materials);
```

MATLAB joins structs into an array only if they have the same fields. To combine `r1` and `r2` above, give `r1` an empty `mimeType`: `r1.mimeType = '';`.

Build and deploy in one step:

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("thermalAnalysis", ...
    resource=materials, ...
    server="http://localhost:9910");
```

---

## How the LLM Accesses Resources

### Discovery

MCP clients discover resources via the `resources/list` protocol method. You can query them from MATLAB:

```MATLAB
resources = prodserver.mcp.list(endpoint, "Resource")
```

Every resource has a fixed URI. Resource templates, URIs with parameters, aren't supported: `resources/templates/list` returns an empty list.

### Reading

The LLM reads a resource by URI. MCP Framework includes a built-in `read_mcp_resource` tool on every server, so resources work regardless of whether the client natively supports resource reads:

```
Tool: read_mcp_resource
Input: {"uri": "mcp://materials/aluminum_6061"}
```

A URI that matches no resource is a failed read, not an empty one: the tool reports an error rather than returning blank content, so an LLM that mistypes a URI is told so instead of concluding the resource exists and is empty. `resources/read` answers the same case with a JSON-RPC error: `-32002` under `2025-06-18`, and `-32602` under `2026-07-28`, which doesn't allow `-32002`.

From MATLAB, use `prodserver.mcp.read` to fetch a resource by URI:

```MATLAB
resources = prodserver.mcp.list(endpoint, "Resource");
result = prodserver.mcp.read(endpoint, resources{1}.uri);
```

### Built-in Resource

Servers built with Invertible encoding automatically include a wire-encoding resource at `mcp://protocol/tools/wire-format/parameters/encoding_rules`. This documents how tool parameters are encoded over the wire. You don't define it — `build` adds it whenever at least one tool uses Invertible encoding. Servers that use only JSON encoding don't include it.

---

## Design Guidelines

1. **Include a catalog resource** that lists all other resources with brief descriptions. This helps the LLM discover what is available without reading everything.

2. **Write clear descriptions.** The LLM uses the `description` field to decide which resources to read. A vague description means it reads resources it does not need.

3. **Use JSON for structured data.** Set `mimeType` to `application/json`. LLMs parse JSON reliably.

4. **Include units in property values.** Engineering data without units is ambiguous. Structure properties as `{"value": 68.9e9, "units": "Pa"}` rather than bare numbers.

5. **One resource per entity.** One material per resource is better than all materials in one resource. The LLM reads only what it needs, conserving tokens.

### URI Schemes

Resource URIs can use any scheme. Choose one that conveys the domain:

| Scheme | Use case | Example |
| :--- | :--- | :--- |
| `mcp://` | General resources | `mcp://materials/steel_304` |
| `data://` | Dataset references | `data://sensors/channel_3` |
| `config://` | Configuration | `config://filter/butterworth` |

The URI must be unique within a server. The scheme is for readability — the framework does not route based on it.

`build` doesn't check uniqueness; reading does. If two resources share a URI, the server builds and lists both, but `resources/read` of that URI fails with error `-32602`, and `prodserver.mcp.read` raises `prodserver:mcp:NonUniqueResource`.

---

## Complete Example

The [Materials example](../../Examples/Materials/Materials.md) demonstrates a full workflow: material property resources paired with structural and thermal analysis tools. The LLM reads the material data it needs, then calls the analysis tools with real values.

--- Copyright 2026 The MathWorks, Inc. ---
