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

This applies uniformly to all MCP operations: tool calls (`tools/call`), resource reads (`resources/read`), and tool listing (`tools/list`).

## Network-Level Access Control

For deployments where authentication is not needed (internal networks, development environments), restrict access at the network level:

- Bind MPS to `localhost` to allow only local connections
- Use firewall rules to restrict which hosts can reach the MPS port
- Deploy behind a reverse proxy that enforces access policies

## MCP-Specific Considerations

### No Per-Tool Authentication

MPS authentication applies at the server level, not per-tool. All tools on an instance share the same authentication configuration. If you need different access levels for different tools, deploy them to separate MPS instances.

### HTTP, Not Streamable HTTP

MCP Framework creates pure HTTP servers. It does not support Streamable HTTP or HTTP with server-sent events (SSE). Each tool call is a single request-response pair. This simplifies security — there are no long-lived connections to manage.

Every way a client can ask for a stream gets an explicit refusal rather than a timeout, so a client can detect the limitation and fall back:

| Request | Response |
| --- | --- |
| Any request to `/<archive>/sse`, the deprecated HTTP+SSE endpoint | `404 Not Found` |
| `GET /<archive>/mcp`, which would open a server-to-client stream | `405 Method Not Allowed`, with `Allow: POST, DELETE` |
| A `POST` whose `Accept` header names `text/event-stream` and no JSON type | `406 Not Acceptable` |

A client that lists both `application/json` and `text/event-stream` — which is what the MCP specification asks clients to send — is served normally in JSON. Only a client that will accept nothing but an event stream is refused. An absent `Accept` header means `*/*` and is served.

All three refusals carry no body and declare `Content-Length: 0`.

### Origin Is Not Validated

The server doesn't check the `Origin` request header. The MCP specification asks servers to validate it as a defense against DNS rebinding, where a malicious web page makes your browser send requests to a server on your machine or network.

Use the [network-level controls](#network-level-access-control) above instead. Binding MPS to `localhost` alone doesn't stop DNS rebinding, because the attacker's requests come from your own browser. Pair it with [authentication](#authentication), or put the server behind a reverse proxy that rejects unexpected `Origin` values.

### Data Marshaling and File Access

When tools use [wrapper functions](./wrapper-functions.md) for large data, the `file:` URLs reference local filesystem paths on the MPS host. Ensure that:

- The MPS process has read access to input data locations
- The MPS process has write access to output data locations
- Data paths are not exposed to untrusted clients (the LLM sees only the URL, but a compromised client could craft arbitrary paths)

### Discovery Endpoint

The [discovery endpoint](./discovery.md) reveals tool names and descriptions. If tool existence is sensitive information, either disable discovery (`discovery=false` in `build`) or restrict network access to the MPS instance.

## See Also

- [MPS Security documentation](https://www.mathworks.com/help/mps/security.html) — full MathWorks reference
- [Protocol Conformance](./protocol-conformance.md) — which parts of the MCP specification the server implements
- [Discovery](./discovery.md) — controlling what information the discovery endpoint exposes
- [`build` reference](../reference/build.md) — the `server` argument accepts `https://` URLs

--- Copyright 2026 The MathWorks, Inc. ---
