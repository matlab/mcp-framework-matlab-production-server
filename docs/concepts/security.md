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

### No per-tool authentication

MPS authentication applies at the server level, not per-tool. All tools on an instance share the same authentication configuration. If you need different access levels for different tools, deploy them to separate MPS instances.

### HTTP, not Streamable HTTP

MCP Framework creates pure HTTP servers. It does not support Streamable HTTP or HTTP with server-sent events (SSE). Each tool call is a single request-response pair. This simplifies security — there are no long-lived connections to manage.

### Data marshaling and file access

When tools use [wrapper functions](./wrapper-functions.md) for large data, the `file:` URLs reference local filesystem paths on the MPS host. Ensure that:

- The MPS process has read access to input data locations
- The MPS process has write access to output data locations
- Data paths are not exposed to untrusted clients (the LLM sees only the URL, but a compromised client could craft arbitrary paths)

### Discovery endpoint

The [discovery endpoint](./discovery.md) reveals tool names and descriptions. If tool existence is sensitive information, either disable discovery (`discovery=false` in `build`) or restrict network access to the MPS instance.

## See Also

- [MPS Security documentation](https://www.mathworks.com/help/mps/security.html) — full MathWorks reference
- [Discovery](./discovery.md) — controlling what information the discovery endpoint exposes
- [`build` reference](../reference/build.md) — the `server` argument accepts `https://` URLs

--- Copyright 2026 The MathWorks, Inc. ---
