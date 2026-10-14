# Protocol Conformance

MCP Framework servers speak MCP revision [`2025-06-18`](https://modelcontextprotocol.io/specification/2025-06-18) over plain HTTP: one JSON-RPC request per `POST`, one response back. This page covers what a client must send, what it gets back, and where the server deliberately departs from the specification.

You don't need this page to build or call tools from MATLAB — `prodserver.mcp.call` handles all of it. Read it when you're writing or debugging a client of your own.

```sh
B=http://localhost:9910/principalStress

# Open a session. The Mcp-Session-Id response header carries the session ID.
curl -i $B/mcp -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"curl","version":"1"}}}'

# Send it back on every later request.
curl -i $B/mcp -H 'Content-Type: application/json' -H "Mcp-Session-Id: $S" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

# End the session.
curl -i -X DELETE $B/mcp -H "Mcp-Session-Id: $S"
```

## Supported Revision

The server supports `2025-06-18` and no other revision.

- `initialize` always answers with `"protocolVersion": "2025-06-18"`, whatever the client asked for. A client pinned to an older revision should treat the mismatch as "this server can't serve me" and stop.
- The `MCP-Protocol-Version` request header may be absent. If it's present, it must be exactly `2025-06-18`. Any other value gets HTTP 400.

## Request Contract

The endpoint is `http://<host>:<port>/<archive>/mcp`. It accepts `POST` for JSON-RPC messages and `DELETE` to end a session. Every other verb gets 405.

| Header | Required | If it's wrong |
| :--- | :--- | :--- |
| `Content-Type` | No. Absent means `application/json`. Case and parameters such as `charset` don't matter. | 415 if it names any other media type |
| `Accept` | No. Absent means `*/*`. | 406 if it lists `text/event-stream` and no JSON-compatible type |
| `MCP-Protocol-Version` | No | 400 if present and not `2025-06-18` |
| `Mcp-Session-Id` | On every request except `initialize` and notifications, including `DELETE` | 400 if absent or blank |

Each `POST` body must be a single JSON object with `"jsonrpc": "2.0"` and a non-empty string `method`. Include `id` for a request; omit it for a notification. A JSON array (a batch) gets `-32600`.

## HTTP Status Codes

| Status | Body | Meaning |
| :--- | :--- | :--- |
| 200 | Yes | Success, a JSON-RPC protocol error, or a tool error. Inspect the body. |
| 202 | No | Notification accepted. Every notification gets 202, including an unknown one. |
| 204 | No | `DELETE` accepted. The session is over. |
| 400 | No | Unsupported `MCP-Protocol-Version`, or missing `Mcp-Session-Id` |
| 404 | No | Any request to `/<archive>/sse` |
| 405 | No | Any verb except `POST` or `DELETE`. The response carries `Allow: POST, DELETE`. |
| 406 | No | The `Accept` header rules out JSON |
| 415 | No | The `Content-Type` header names a type other than `application/json` |
| 500 | Yes | Internal server error, always JSON-RPC code `-32603` |

**HTTP 200 doesn't mean success.** A JSON-RPC error is a protocol failure, not a transport failure, so it travels over HTTP 200. Only `-32603` gets a 500.

Refusals (400, 404, 405, 406, 415) have no body, so there's no JSON-RPC error code to read. If your client sees an empty 400, check the two headers in the table above.

**`curl -d` needs `-H 'Content-Type: application/json'`.** Without it, curl declares the body `application/x-www-form-urlencoded` and the server answers 415.

## JSON-RPC Error Codes

An error response has an `error` member and no `result` member. Its `id` echoes the request, or is `null` when the request was too malformed to carry one.

```json
{ "jsonrpc": "2.0", "id": 7, "error": { "code": -32601, "message": "mcpHandler:422 : Invalid or unsupported MCP method foo/bar" } }
```

| Code | HTTP | Raised when |
| :--- | :--- | :--- |
| `-32700` | 200 | The body is empty or isn't valid JSON |
| `-32600` | 200 | Valid JSON, but not a single JSON-RPC 2.0 request: a batch, a bare value such as `42`, `"str"` or `null`, a missing or wrong `jsonrpc`, or a missing or empty `method` |
| `-32601` | 200 | The server doesn't implement `method`. Includes `prompts/list` and `resources/templates/list`. |
| `-32602` | 200 | `params` is missing something or names something that doesn't exist: an unknown tool, a missing required tool argument, no `params.name`, no `params.uri`, or no `params.protocolVersion` on `initialize` |
| `-32603` | 500 | A fault inside the server, such as tool definitions that fail to load. See [Several Archives on One Server](../reference/deploy.md#several-archives-on-one-server). |
| `-32002` | 200 | `resources/read` named a URI the server doesn't host |

Match on `error.code`, not `error.message`. The message starts with a MATLAB source location that changes between releases.

## Tool Errors

When a tool runs and raises a MATLAB error, the client gets HTTP 200 with a normal `result` that has `isError` set. There's no JSON-RPC `error` member:

```json
{
  "jsonrpc": "2.0",
  "id": 7,
  "result": {
    "isError": true,
    "content": [ { "type": "text", "text": "principalStress:31 : Index exceeds array bounds." } ]
  }
}
```

This follows the MCP specification. The tool's error text reaches the LLM, which can correct its arguments and try again. A protocol error, by contrast, tells the *client* it sent something wrong.

Check the two channels in this order:

```
if the body has an "error" member   -> protocol error; read error.code
else if result.isError is true      -> the tool ran and raised
else                                -> success; read result
```

An unknown tool name or a missing required argument is a protocol error (`-32602`), not a tool error. The server rejects those before the tool runs.

`prodserver.mcp.call` keeps the two channels apart: a tool error raises `prodserver:mcp:ToolError`, and a protocol error raises `prodserver:mcp:RemoteError`.

## Sessions

`initialize` creates a session ID and returns it in the `Mcp-Session-Id` response header. Send it on every later request and on the closing `DELETE`.

The server checks only that the header is present and not blank. It never looks the value up. As a result:

- It accepts any non-blank value, including one it never issued.
- A session keeps working after `DELETE`. The specification says the server should answer 404 from then on. This server doesn't.

That's deliberate. MATLAB Production Server sends each request to whichever worker is free, and workers share no state. A session registry would live on one worker. `initialize` would succeed on worker A and the next `tools/call` would get 404 from worker B. Rejecting valid sessions at random is worse than not checking them.

`initialize` and notifications don't need the header. Clients commonly send `notifications/initialized` before they've stored the session ID, and JSON-RPC forbids replying to a notification anyway.

## Not Supported

| Feature | What a client sees |
| :--- | :--- |
| Streamable HTTP and SSE | `GET /mcp` gets 405, `/sse` gets 404, and an SSE-only `Accept` gets 406. See [Security](./security.md#http-not-streamable-http). |
| JSON-RPC batches | `-32600` |
| `prompts/*`, `resources/templates/list` | `-32601`. Neither is advertised in `initialize`. |
| Server-to-client requests and notifications | Never sent |
| `Origin` validation | Not performed. See [Security](./security.md#origin-is-not-validated). |

## See Also

- [Client Configuration](../guides/client-configuration.md#troubleshooting) — symptoms and fixes for clients that can't connect
- [Security](./security.md) — transport security and access control
- [Wire Encoding](./wire-encoding.md) — how MATLAB values are encoded in tool arguments and results

--- Copyright 2026 The MathWorks, Inc. ---
