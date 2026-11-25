# Security

MCP Framework creates HTTP-based MCP servers hosted by MATLAB Production Server. Security is configured at the MPS level — the framework inherits whatever authentication, encryption, and access control MPS provides.

## Transport Security

MPS supports HTTPS for encrypted communication. When configured with TLS certificates, all MCP traffic (tool calls, resource reads, discovery queries) is encrypted in transit.

Configure HTTPS in the MPS `main_config`: the port to listen on for HTTPS, the server's certificate chain and its private key.

```
--https 9920
--x509-cert-chain /path/to/server.crt
--x509-private-key /path/to/server.key
```

After enabling HTTPS, use `https://` in your server URLs:

```MATLAB
[ctf, endpoint] = prodserver.mcp.build("principalStress", ...
    example=@() principalStress([120 -50 80], "max"), ...
    server="https://myserver:9920");
```

Clients must also use `https://` when connecting.

## Authentication

MPS supports [OAuth 2.0 and OpenID Connect (OIDC)](https://www.mathworks.com/help/mps/security.html) for client authentication. When configured, clients must present valid tokens before calling tools.

Authentication applies to every request, not only tool calls: listing tools, reading resources, and `server/discover` or `initialize` need a valid token too.

## Network-Level Access Control

For deployments where authentication is not needed (internal networks, development environments), restrict access at the network level:

- Bind MPS to `localhost` to allow only local connections
- Use firewall rules to restrict which hosts can reach the MPS port
- Deploy behind a reverse proxy that enforces access policies

## MCP-Specific Considerations

### No Per-Tool Authentication

MPS authentication applies at the server level, not per-tool. All tools on an instance share the same authentication configuration. If you need different access levels for different tools, deploy them to separate MPS instances.

### Streamable HTTP, JSON Only

MCP Framework servers use the Streamable HTTP transport in its JSON-only mode. Every `POST` gets a single `application/json` response, and the server never opens a server-sent events (SSE) stream. Each tool call is a single request-response pair. This simplifies security — there are no long-lived connections to manage. With no stream, the server can't notify clients of changes, so it advertises `listChanged: false`: the tool and resource lists are fixed when the archive is built.

Every way a client can ask for a stream gets an explicit refusal rather than a timeout, so a client can detect the limitation and fall back:

| Request | Response |
| --- | --- |
| `GET /<archive>/mcp`, which would open a server-to-client stream | `405 Method Not Allowed`, with `Allow: POST, DELETE`, under either revision |
| A `POST` whose `Accept` header rules out JSON, such as one that names only `text/event-stream` | `406 Not Acceptable` |

A client that lists both `application/json` and `text/event-stream` — which is what the MCP specification asks clients to send — is served normally in JSON. Only a client that will accept nothing but an event stream is refused. An absent `Accept` header means `*/*` and is served.

Both refusals carry no body and declare `Content-Length: 0`. They are the only responses without one: every other error has a JSON-RPC body. There is no `/<archive>/sse` endpoint for the deprecated HTTP+SSE transport, so MATLAB Production Server answers requests to it with 404.

### Origin Is Not Validated

The server doesn't check the `Origin` request header. The MCP specification asks servers to validate it as a defense against DNS rebinding, where a malicious web page makes your browser send requests to a server on your machine or network.

Use the [network-level controls](#network-level-access-control) above instead. Binding MPS to `localhost` alone doesn't stop DNS rebinding, because the attacker's requests come from your own browser. Pair it with [authentication](#authentication), or put the server behind a reverse proxy that rejects unexpected `Origin` values.

### Session IDs Are Not Authenticators

Under `2025-06-18`, the session ID carries the capabilities the client declared in `initialize`, so that any worker can serve any request. The server doesn't sign it. It accepts any well-formed token, including one a client made itself, carrying whatever capabilities that client chose. So a session ID proves nothing about who sent the request or what it may do. Use [authentication](#authentication) for that. See [Sessions](./protocol-conformance.md#sessions).

### Cached List Results

Under `2026-07-28`, the results of `server/discover`, `tools/list`, `resources/list` and `resources/templates/list` carry `cacheScope: public` and `ttlMs: 300000`. They tell a client, or an MCP-aware cache between client and server, that it may keep the result for 5 minutes and share it with other users. The hints are in the JSON result, not in HTTP cache headers. `resources/read` results are `private`, for one user only, for 1 minute.

That's safe while every user of an archive sees the same tools. Suppose you put the server behind a shared MCP cache or gateway, and restrict who may reach an archive. A user who isn't allowed to call the server can then still get its tool list from the cache, for up to 5 minutes after someone else fetched it. Restrict access at the cache too, or don't share one cache between users with different access.

A server with an MCP App is the exception. Its `tools/list` depends on the client, since only clients that support MCP Apps see `uri2json`, so the server sends it with `cacheScope: private` and `ttlMs: 0`. No cache should keep it, so one client's list can't reach another.

### Data Marshaling and File Access

When tools use [wrapper functions](./wrapper-functions.md) for large data, the `file:` URLs name paths the MPS process opens. On Windows, that includes a UNC path on another machine, such as `file:////server/share/x.mat`: a client can make the server open an SMB connection to any host it names, with the MPS account's credentials. Block outbound SMB (port 445) from MPS hosts, or run MPS under an account with no network credentials. Ensure that:

- The MPS process has read access to input data locations
- The MPS process has write access to output data locations
- Data paths are not exposed to untrusted clients (the LLM sees only the URL, but a compromised client could craft arbitrary paths)

### MCP Apps and `uri2json`

A server built with an [MCP App](../guides/mcp-apps.md) has a `uri2json` tool. The app's view uses it to read the data behind a URL, such as a tool's result file. It reads a registered resource, or anything the MPS process can reach through the URL's scheme: any `file:` path, and `redis:`, `kafka:` and `workspace:` locations. It returns the data itself.

The server keeps `uri2json` away from the LLM in two ways:

- **Its definition marks it `visibility: ["app"]`.** A host that supports MCP Apps leaves it out of the model's tool list, and lets only the view call it.
- **The server offers it only to clients that declare MCP Apps support** (`io.modelcontextprotocol/ui`). Any other client doesn't see it in `tools/list`, and gets the unknown-tool error if it calls it. The archive's `/signature` route describes it only to a request whose `2025-06-18` session declared MCP Apps support. A request with no session, such as any `2026-07-28` client's, doesn't see it there. The server counts each refusal in `MCP_uri2json_Refused`; see [Server Metrics](../guides/server-metrics.md).

That stops the model from calling `uri2json`, whether by mistake or because a document it read told it to. It doesn't stop a program that connects to the server directly: that can claim MCP Apps support, in `initialize`, in `_meta` or in a session ID it made itself (see [Session IDs](#session-ids-are-not-authenticators)), and pass `uri2json` any URL. A wrapper function's `file:` URLs already give such a caller the same reach, but `uri2json` returns the raw data. Control who can connect with [authentication](#authentication) and [network-level access control](#network-level-access-control).

A host that declares MCP Apps support but doesn't honor `visibility` would still show `uri2json` to its model. The server can't detect that.

### Discovery Endpoint

The [discovery endpoint](./discovery.md) reveals tool names and descriptions. Up to R2026b, `discovery=false` in `build` leaves the archive out of `/api/discovery`. From R2027a, the archive is listed anyway, with a stand-in entry for each function; see [Discovery](./discovery.md#step-1-find-the-archives). Neither hides the tools: any client that can reach `/<archive>/mcp` still gets them from `tools/list`. If tool existence is sensitive information, restrict network access to the MPS instance or require [authentication](#authentication).

## See Also

- [MPS Security documentation](https://www.mathworks.com/help/mps/security.html) — full MathWorks reference
- [Protocol Conformance](./protocol-conformance.md) — which parts of the MCP specification the server implements
- [Discovery](./discovery.md) — controlling what information the discovery endpoint exposes
- [`build` reference](../reference/build.md) — the `server` argument accepts `https://` URLs

--- Copyright 2026 The MathWorks, Inc. ---
