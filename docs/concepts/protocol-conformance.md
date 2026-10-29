# Protocol Conformance

MCP Framework servers speak two MCP revisions over plain HTTP: [`2025-06-18`](https://modelcontextprotocol.io/specification/2025-06-18), which uses sessions, and [`2026-07-28`](https://modelcontextprotocol.io/specification/2026-07-28), which doesn't. Each `POST` carries one JSON-RPC request and gets one response. This page covers how the server decides which revision a request uses, what a client must send under each one, what it gets back, and where the server deliberately departs from the specification.

You don't need this page to build or call tools from MATLAB — `prodserver.mcp.call` handles all of it. It sends `server/discover` first and falls back to `initialize` if the server doesn't answer. Read this page when you're writing or debugging a client of your own.

```sh
B=http://localhost:9910/principalStress

# 2026-07-28: no session. Every request states its version and capabilities in _meta,
# and repeats the method in the Mcp-Method header.
curl -i $B/mcp -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2026-07-28' -H 'Mcp-Method: tools/list' \
  -d '{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}'

# 2025-06-18: open a session. The Mcp-Session-Id response header carries the session ID.
curl -i $B/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'

# Send the session ID back on every later request.
curl -i $B/mcp -H 'Content-Type: application/json' -H "Mcp-Session-Id: $S" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

# End the session.
curl -i -X DELETE $B/mcp -H "Mcp-Session-Id: $S"
```

## Supported Revisions

| Revision | Model | Also serves |
| :--- | :--- | :--- |
| `2026-07-28` | Stateless. Each request restates the version in `params._meta`. | — |
| `2025-06-18` | A session, opened by `initialize` | `2025-03-26` and `2024-11-05` in the `MCP-Protocol-Version` header |

The aliases affect routing only. `server/discover` lists `2025-06-18` and `2026-07-28` and nothing else, and `initialize` never answers with an alias.

## How a Request Gets a Revision

The server reads the request's shape first, newest revision first:

1. **`params._meta` holds a per-request protocol field** (`io.modelcontextprotocol/protocolVersion`, `clientCapabilities`, `clientInfo` or `logLevel`): `2026-07-28`. Other `_meta` keys, such as `progressToken`, don't count, because both revisions use them.
2. **The method is `initialize`, or the request has a non-blank `Mcp-Session-Id` header**: `2025-06-18`.
3. **Neither**: `-32602` with HTTP 400. The server can't tell which revision the client means.

Then it checks the version:

- **A version in `_meta` decides.** The `MCP-Protocol-Version` header may be absent. If it's present and doesn't match, the server answers `-32020`. A version the server doesn't support gets `-32022`.
- **Otherwise the header is checked but the shape stands.** An absent header is fine. A header naming an unsupported version gets `-32022`.

A `-32022` response tells the client what to send instead:

```json
{ "jsonrpc": "2.0", "id": 1, "error": { "code": -32022, "message": "...",
  "data": { "supported": ["2025-06-18", "2026-07-28"], "requested": "2027-01-01" } } }
```

`2025-06-18` defines no code for an unsupported version, so the server borrows `-32022` from `2026-07-28` for both revisions.

## Request Contract

The endpoint is `http://<host>:<port>/<archive>/mcp`. It accepts `POST` for JSON-RPC messages and `DELETE` to end a `2025-06-18` session. Every other verb gets 405.

### Every Request

| Header | Required | If it's wrong |
| :--- | :--- | :--- |
| `Content-Type` | Yes, `application/json`. Case and parameters such as `charset` don't matter. | 415 with `-32600` if it's absent or names any other media type |
| `Accept` | No. Absent means anything goes. | 406 on a `POST` that rules out JSON. `application/json`, `application/*` and `*/*` all admit it. |

Each `POST` body must be a single JSON object with `"jsonrpc": "2.0"`, a non-empty string `method`, and a non-null `id`. Omit `id` only for a notification. An empty body, a JSON array (a batch) or any other JSON value gets `-32600`.

**`curl -d` needs `-H 'Content-Type: application/json'`.** Without it, curl declares the body `application/x-www-form-urlencoded` and the server answers 415.

### 2026-07-28

`params._meta` must carry:

| `_meta` key | If it's missing |
| :--- | :--- |
| `io.modelcontextprotocol/protocolVersion` | `-32602`, HTTP 400 |
| `io.modelcontextprotocol/clientCapabilities` (the server also accepts `io.modelcontextprotocol/capabilities`) | `-32602`, HTTP 400 |
| `io.modelcontextprotocol/clientInfo` | Optional |

And the request must carry these headers:

| Header | Required | Value |
| :--- | :--- | :--- |
| `MCP-Protocol-Version` | Always | The version in `_meta` |
| `Mcp-Method` | Always | The body's `method`, exactly |
| `Mcp-Name` | For `tools/call` and `resources/read` | The body's `params.name` (the tool) or `params.uri` (the resource) |

A missing header or a value that doesn't match the body gets `-32020` with HTTP 400. A name that can't travel as plain ASCII may be Base64-encoded: `=?base64?<UTF-8 bytes in Base64>?=`. The sentinel is lowercase. The server decodes the value before comparing it with the body.

```sh
curl -i $B/mcp -H 'Content-Type: application/json' \
  -H 'MCP-Protocol-Version: 2026-07-28' -H 'Mcp-Method: tools/call' -H 'Mcp-Name: principalStress' \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"principalStress","arguments":{"stressState":[120,-50,80],"component":"max"},"_meta":{"io.modelcontextprotocol/protocolVersion":"2026-07-28","io.modelcontextprotocol/clientCapabilities":{}}}}'
```

### 2025-06-18

| Header | Required | If it's wrong |
| :--- | :--- | :--- |
| `Mcp-Session-Id` | On every request except `initialize` and notifications, including `DELETE` | Without it, a `POST` can't be assigned a revision (`-32602`, HTTP 400) and a `DELETE` gets 405 |
| `MCP-Protocol-Version` | No | `-32022`, HTTP 400, if it names a version the server doesn't support |

## Methods

| Method | 2025-06-18 | 2026-07-28 |
| :--- | :--- | :--- |
| `initialize` | Yes. Opens a session. | `-32601`, HTTP 404 |
| `server/discover` | `-32601` | Yes. Returns `supportedVersions`, `capabilities` and `instructions`. |
| `ping` | Yes. Returns an empty result. | `-32601`, HTTP 404. Use `server/discover`, or `GET /<archive>/ping`. |
| `tools/list`, `tools/call` | Yes | Yes |
| `resources/list`, `resources/read` | Yes | Yes |
| `resources/templates/list` | Yes. Always returns an empty list. | Yes. Always returns an empty list. |
| `prompts/*` | `-32601` | `-32601`, HTTP 404 |
| `notifications/*` | HTTP 202, no body | HTTP 202, no body |

Both `initialize` and `server/discover` advertise the `tools` and `resources` capabilities, each with `listChanged: false`. The lists are fixed when the archive is built.

**Notifications.** Any `POST` whose method starts with `notifications/` gets 202 and no body, under either revision, as soon as its body passes the `Content-Type` and JSON checks. That includes an unknown notification and one sent before `initialize`. The server ignores a notification's own failures, since JSON-RPC forbids replying to one.

**`initialize`.** The server answers with `"protocolVersion": "2025-06-18"`, whatever the client asked for. A client pinned to another revision should treat the mismatch as "this server can't serve me" and stop. `serverInfo.title` is the archive name, except for a client that asked for a `2024` revision.

**`GET /<archive>/ping`** isn't MCP. It returns `pong` as `text/plain`, under any revision, and works for a liveness check. See [`prodserver.mcp.ping`](../reference/ping.md). A deployed archive also names its build in the `MATLAB-MCP-Archive-UUID` header, the same value the server's discovery API reports as `archiveUuid`. [`prodserver.mcp.deploy`](../reference/deploy.md) uses it to tell an updated archive from the one it replaces.

### 2026-07-28 Responses

Every result carries:

- `resultType: "complete"`.
- `_meta["io.modelcontextprotocol/serverInfo"]` with the server's `name`, `version` and `title`, the archive name.

Results that a client may cache also carry `ttlMs` and `cacheScope`:

| Methods | `ttlMs` | `cacheScope` |
| :--- | :--- | :--- |
| `server/discover`, `tools/list`, `resources/list`, `resources/templates/list` | `300000` (5 minutes) | `public` |
| `resources/read` | `60000` (1 minute) | `private` |

`tools/call` results carry neither. Responses have the header `MCP-Protocol-Version: 2026-07-28`, except when a version check fails (`-32020` for a mismatched version header, or `-32022`). Those are answered before the revision is settled.

## HTTP Status Codes

Every response carries `Server: MATLAB Production Server/Model Context Protocol`.

| Status | Body | Meaning |
| :--- | :--- | :--- |
| 200 | Yes | Success, a tool error, or a JSON-RPC error that blames the request's content. Inspect the body. |
| 202 | No | Notification accepted |
| 204 | No | `2025-06-18` `DELETE` accepted. The session is over. |
| 400 | Yes | The request is malformed, can't be assigned a revision, names an unsupported version, or breaks a `2026-07-28` rule. See the code. |
| 404 | Yes | `2026-07-28`: the server doesn't implement the method (`-32601`). Either revision: the path names no archive (`-32600`). |
| 405 | No | A verb other than `POST` or `DELETE`, or a `DELETE` with no session. The response carries `Allow: POST, DELETE`. A `DELETE` assigned to `2026-07-28`, which has no sessions, gets `Allow: POST`. |
| 406 | No | A `POST` whose `Accept` header rules out JSON |
| 415 | Yes | `Content-Type` is absent or isn't `application/json` (`-32600`) |
| 500 | Yes | Internal server error, always `-32603` |

**HTTP 200 doesn't mean success.** Under `2025-06-18`, a JSON-RPC error travels over HTTP 200 unless it's an internal error. `2026-07-28` moves more errors to 400 and 404, but an unknown tool or bad arguments still get 200.

Only 405 and 406 have no body. Every other refusal has a JSON-RPC error you can read.

## JSON-RPC Error Codes

An error response has an `error` member and no `result` member. Its `id` echoes the request, or is `null` when the request was too malformed to carry one.

```json
{ "jsonrpc": "2.0", "id": 7, "error": { "code": -32601, "message": "ProtocolDispatcher:57 : Method not found: foo/bar" } }
```

| Code | 2025-06-18 | 2026-07-28 | Raised when |
| :--- | :--- | :--- | :--- |
| `-32700` | 400 | 400 | The body isn't valid JSON |
| `-32600` | 400 | 400 | The body is empty, or isn't a single JSON-RPC 2.0 request: a batch, a bare value, a missing or wrong `jsonrpc`, a missing or empty `method`, or a missing `id`. Also returned with 415 and with 404 (see above). |
| `-32601` | 200 | 404 | The server doesn't implement `method` (see [Methods](#methods)) |
| `-32602` | 200 | 200 | `params` is wrong: an unknown tool, no `params.name` or `params.uri`, or no `params.protocolVersion` on `initialize`. Under `2025-06-18`, also tool arguments that fail validation (see [Tool Arguments](#tool-arguments)). Under `2026-07-28`, also a URI the server doesn't host. |
| `-32602` | 400 | 400 | The request can't be assigned a revision. Under `2026-07-28`, also a missing `_meta` field. |
| `-32002` | 200 | — | `resources/read` named a URI the server doesn't host |
| `-32020` | — | 400 | A required header is missing, or doesn't match the body |
| `-32022` | 400 | 400 | The request names a version the server doesn't support. `error.data` lists `supported` and `requested`. |
| `-32603` | 500 | 500 | A fault inside the server, such as tool definitions that fail to load. See [Several Archives on One Server](../reference/deploy.md#several-archives-on-one-server). |

`2026-07-28` doesn't allow `-32002`, so the same mistake gets `-32602` there.

Match on `error.code`, not `error.message`. The message starts with a MATLAB source location that changes between releases.

## Tool Errors

When a tool runs and raises a MATLAB error, the client gets HTTP 200 with a normal `result` that has `isError` set. There's no JSON-RPC `error` member:

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "isError": true,
    "content": [ { "type": "text", "text": "Output argument \"sigma\" (and possibly others) not assigned a value in the execution with \"principalStress\" function." } ]
  }
}
```

This follows the MCP specification, under both revisions. The tool's error text reaches the LLM, which can correct its arguments and try again. A protocol error, by contrast, tells the *client* it sent something wrong.

Check the two channels in this order:

```
if the body has an "error" member   -> protocol error; read error.code
else if result.isError is true      -> the tool ran and raised
else                                -> success; read result
```

An unknown tool name is a protocol error (`-32602`), not a tool error. The server rejects it before any tool runs.

### Tool Arguments

Before it runs a tool, the server checks the call's `arguments` against the tool's published `inputSchema`. A call fails the check if it:

- has no `arguments` object, when the tool has required inputs
- has an `arguments` value that isn't a JSON object, such as an array
- leaves out a required argument
- has an argument the tool doesn't take
- has a value the schema rejects, such as the string `"3"` for a number, or `7` for a string
- has a value that can't be decoded, such as a date that doesn't exist

The check reads the schema with MATLAB's array rules: a single value satisfies an array schema, since a MATLAB scalar is a 1x1 array. Under Invertible encoding, a scalar may be sent bare instead of in its `type`, `size` and `data` wrapper, as the [encoding rules](./wire-encoding.md) allow. Under the invertible encoding, a bare string is a number only if it's `"NaN"`, `"Inf"` or `"-Inf"`.

The two revisions report a failed check differently, as each specification requires:

- **`2025-06-18`**: a protocol error, `-32602` over HTTP 200.
- **`2026-07-28`**: a tool execution error, so that the model reads the message and can correct its call. The result has `isError` set, and its text begins `Input validation error:`, for example `Input validation error: Argument 'n': expected number, got string.`

Either way, the tool doesn't run. A value the schema allows but the tool's arguments block rejects, such as a negative number for an argument declared `{mustBePositive}`, does reach the tool, and its error is a tool error under both revisions.

`prodserver.mcp.call` keeps the two channels apart: a tool error raises `prodserver:mcp:ToolError`, and a protocol error raises `prodserver:mcp:JsonRpcError`, or `prodserver:mcp:RemoteError` for the codes that can mean a wrong revision.

## Sessions

Sessions exist only in `2025-06-18`. `initialize` creates a session ID (a UUID) and returns it in the `Mcp-Session-Id` response header. Send it on every later request and on the closing `DELETE`. Responses echo it back.

The server checks only that the header is present and not blank. It never looks the value up. As a result:

- It accepts any non-blank value, including one it never issued.
- A session keeps working after `DELETE`. The specification says the server should answer 404 from then on. This server doesn't.

That's deliberate. MATLAB Production Server sends each request to whichever worker is free, and workers share no state. A session registry would live on one worker. `initialize` would succeed on worker A and the next `tools/call` would get 404 from worker B. Rejecting valid sessions at random is worse than not checking them. `2026-07-28` removes the problem: it has no sessions at all.

`initialize` and notifications don't need the header. Clients commonly send `notifications/initialized` before they've stored the session ID.

## Not Supported

| Feature | What a client sees |
| :--- | :--- |
| SSE streams | The server uses Streamable HTTP in JSON-only mode. `GET /mcp` gets 405, and an `Accept` header without JSON gets 406. There's no SSE endpoint. See [Security](./security.md#streamable-http-json-only). |
| JSON-RPC batches | `-32600` |
| `prompts/*` | `-32601`. Not advertised in `initialize` or `server/discover`. |
| Resource templates | `resources/templates/list` returns an empty list |
| Server-to-client requests and notifications | Never sent |
| `Origin` validation | Not performed. See [Security](./security.md#origin-is-not-validated). |

## See Also

- [Client Configuration](../guides/client-configuration.md#troubleshooting) — symptoms and fixes for clients that can't connect
- [Security](./security.md) — transport security and access control
- [Wire Encoding](./wire-encoding.md) — how MATLAB values are encoded in tool arguments and results

--- Copyright 2026 The MathWorks, Inc. ---
