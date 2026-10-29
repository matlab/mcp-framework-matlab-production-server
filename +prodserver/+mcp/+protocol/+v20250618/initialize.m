function [result, httpCode, httpMsg, msgHeaders] = initialize(jrpc, serverName)
%initialize Handle MCP initialize request for v2025-06-18.
%   Negotiates protocol version, advertises capabilities derived from
%   ProtocolDispatcher, and mints a session ID.
%
%   SERVERNAME, the archive name, is reported as serverInfo.title. Empty
%   (the default, for callers with no request path) omits the title rather
%   than inventing one.
%
%   The returned headers are the whole of this response's protocol headers:
%   the minted session id and the negotiated version. Adapter.responseHeaders
%   adds neither to an initialize response, so the minted id replaces any
%   the request carried (ND3) and the header agrees with the body (ND4).

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        jrpc
        serverName string = ""
    end

    import prodserver.mcp.MCPConstants
    import prodserver.mcp.protocol.v20250618.Constants

    [result, httpCode, httpMsg, msgHeaders, r] = ...
        prodserver.mcp.handler.internal.initResult(jrpc);
    result.id = jrpc.id;

    % A missing or non-text protocolVersion is a malformed request, not a
    % negotiation: -32602, rather than the -32603/500 a raw field access or
    % string() conversion would produce (XD1).
    if ~prodserver.mcp.internal.hasField(jrpc, "params.protocolVersion") || ...
            ~isText(jrpc.params.protocolVersion)
        error("prodserver:mcp:InvalidParams", ...
            "initialize requires a 'protocolVersion' string parameter.");
    end
    requested = string(jrpc.params.protocolVersion);

    % Negotiate (G6). The spec: echo the requested version if supported,
    % otherwise answer with another version we support. Only versions this
    % handshake reaches count -- 2026-07-28 is supported but has no
    % initialize at all, and the 2024-11-05 alias is the HTTP+SSE transport
    % this server does not provide -- so neither is ever echoed.
    %
    % The rule is "the newest version that defines initialize". Exactly one
    % does today, so it is written down here. When a second arrives, replace
    % this with a predicate over the ProtocolRegistry, not another string.
    handshakeVersions = Constants.Version;
    if ismember(requested, handshakeVersions)
        negotiated = requested;
    else
        negotiated = handshakeVersions(end);
    end

    r.capabilities = prodserver.mcp.protocol.capabilities();

    session = matlab.lang.internal.uuid;

    r.protocolVersion = negotiated;
    % No title for a 2024-era client. Keyed on the REQUESTED version: the
    % negotiated one is never a 2024 version, so testing it would always
    % send title to the client this exists to shield.
    if contains(requested, "2024")
        serverName = "";
    end
    r.serverInfo = prodserver.mcp.protocol.serverInfo(serverName);

    msgHeaders = vertcat(msgHeaders, ...
        { Constants.SessionId char(session); ...
          char(MCPConstants.ProtocolVersion) char(negotiated) });

    result.result = r;
end

function tf = isText(v)
    tf = (ischar(v) && isrow(v)) || (isstring(v) && isscalar(v) && ~ismissing(v));
end
