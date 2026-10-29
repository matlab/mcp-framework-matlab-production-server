# Security

MCP Framework creates HTTP-based MCP servers hosted by MATLAB Production Server. Security is configured at the MPS level — the framework inherits whatever authentication, encryption, and access control MPS provides.

## Transport Security

MPS supports HTTPS for encrypted communication. When configured with TLS certificates, all MCP traffic (tool calls, resource reads, discovery queries) is encrypted in transit.

Configure HTTPS in the MPS `main_config`:

```
--ssl
--ssl-cert-file /path/to/server.crt
--ssl-key-file /path/to/server.key
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

### Cached List Results

Under `2026-07-28`, the results of `server/discover`, `tools/list`, `resources/list` and `resources/templates/list` carry `cacheScope: public` and `ttlMs: 300000`. They tell a client, or an MCP-aware cache between client and server, that it may keep the result for 5 minutes and share it with other users. The hints are in the JSON result, not in HTTP cache headers. `resources/read` results are `private`, for one user only, for 1 minute.

That's safe while every user of an archive sees the same tools, which is always true today. If you put the server behind a shared MCP cache or gateway and restrict who may reach an archive, a user who isn't allowed to call the server can still be served its tool list from the cache, for up to 5 minutes after someone else fetched it. Restrict access at the cache too, or don't share one cache between users with different access.

### Data Marshaling and File Access

When tools use [wrapper functions](./wrapper-functions.md) for large data, the `file:` URLs reference local filesystem paths on the MPS host. Ensure that:

- The MPS process has read access to input data locations
- The MPS process has write access to output data locations
- Data paths are not exposed to untrusted clients (the LLM sees only the URL, but a compromised client could craft arbitrary paths)

### Discovery Endpoint

The [discovery endpoint](./discovery.md) reveals tool names and descriptions. `discovery=false` in `build` leaves the archive out of `/api/discovery`, but it doesn't hide the tools: any client that can reach `/<archive>/mcp` still gets them from `tools/list` and `server/discover`. If tool existence is sensitive information, restrict network access to the MPS instance or require [authentication](#authentication).

## See Also

- [MPS Security documentation](https://www.mathworks.com/help/mps/security.html) — full MathWorks reference
- [Protocol Conformance](./protocol-conformance.md) — which parts of the MCP specification the server implements
- [Discovery](./discovery.md) — controlling what information the discovery endpoint exposes
- [`build` reference](../reference/build.md) — the `server` argument accepts `https://` URLs

--- Copyright 2026 The MathWorks, Inc. ---
