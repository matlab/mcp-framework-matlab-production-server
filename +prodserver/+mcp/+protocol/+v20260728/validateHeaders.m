function validateHeaders(request, jrpc, metaVersion)
%validateHeaders Validate HTTP headers match body per 2026-07-28 spec.
%   Required headers are enforced strictly (D40): absent is a failure, not a
%   pass. Every failure is prodserver:mcp:HeaderMismatch, which both
%   mapErrorCode and the preDetectionError hook render as -32020 over HTTP
%   400 -- the status the spec mandates for this family.
%
%   Strictness is why this runs only here. The MUST to reject a header-less
%   request binds a server that does not serve clients older than
%   2025-06-18; we alias 2024-11-05 and 2025-03-26 onto 2025-06-18, so we
%   sit in the spec's MAY branch and a header-less request is fatal only
%   once it has been attributed to THIS revision. Reaching this function is
%   that attribution.

% Copyright 2026 The MathWorks, Inc.

    C = prodserver.mcp.protocol.v20260728.Constants;
    import prodserver.mcp.internal.getHeaderValue

    % One guard, at the top. Headers arrive as an Nx2 cell array and
    % getHeaderValue rejects anything that is not two columns wide, which a
    % header-less request's {} is not. Normalising here is what makes a
    % request with no headers at all fail as the -32020 it is, rather than
    % as a 500 about name-value pairs.
    headers = cell(0,2);
    if isfield(request, 'Headers') && ~isempty(request.Headers)
        headers = request.Headers;
    end

    % A second look at a question ProtocolRegistry.resolve has already
    % settled -- see checkVersionHeader for why both sites make the call.
    % Through mcpHandler the mismatch arm can never fire, because resolve
    % raises first; it stays so that the header authority for this revision
    % does not appear to ignore the version header.
    %
    % Presence is checked here and NOT in checkVersionHeader, which resolve
    % also calls. resolve runs for every request of every revision, and a
    % 2025-06-18 request carrying no version header is legal; making absence
    % fatal in the shared helper would reject it before any adapter saw it.
    % The shared helper compares values; this file requires the value.
    pv = prodserver.mcp.internal.headerVersion(request);
    if strlength(pv) == 0
        error("prodserver:mcp:HeaderMismatch", ...
            "%s header is required by MCP %s and was not sent.", ...
            prodserver.mcp.MCPConstants.ProtocolVersion, C.Version);
    end
    prodserver.mcp.protocol.v20260728.checkVersionHeader(pv, metaVersion);

    headerMethod = getHeaderValue(C.McpMethod, headers);
    if isempty(headerMethod)
        error("prodserver:mcp:HeaderMismatch", ...
            "%s header is required by MCP %s and was not sent.", ...
            C.McpMethod, C.Version);
    end
    if ~strcmp(string(headerMethod), string(jrpc.method))
        error("prodserver:mcp:HeaderMismatch", ...
            "Mcp-Method header '%s' does not match body method '%s'.", ...
            headerMethod, jrpc.method);
    end

    % Required for the three methods that name a thing, and for no others.
    % The list is nameFromParams', shared with the client that emits the
    % header, because a header one side demands and the other omits is a
    % -32020 on a request that was never wrong.
    [bodyName, nameRequired] = ...
        prodserver.mcp.protocol.v20260728.nameFromParams(jrpc);
    if ~nameRequired
        return
    end

    headerName = getHeaderValue(C.McpName, headers);
    if isempty(headerName)
        error("prodserver:mcp:HeaderMismatch", ...
            "%s header is required for method '%s' and was not sent.", ...
            C.McpName, jrpc.method);
    end

    % Decode before comparing, never after. The client MUST wrap a value
    % that cannot travel as plain ASCII in the Base64 sentinel, so the
    % header and the body legitimately differ byte for byte on exactly the
    % requests this revision was extended to carry.
    headerName = prodserver.mcp.protocol.v20260728.decodeHeaderValue( ...
        headerName);

    % An empty bodyName here means the method requires a name and the body
    % did not supply one, which is a mismatch rather than nothing to check.
    % Skipping it -- as this function used to -- accepts any Mcp-Name
    % whatsoever on a malformed tools/call.
    if strlength(bodyName) == 0
        error("prodserver:mcp:HeaderMismatch", ...
            "%s header '%s' was sent but method '%s' supplied no name " + ...
            "in params to match it against.", ...
            C.McpName, headerName, jrpc.method);
    end

    if ~strcmp(headerName, bodyName)
        error("prodserver:mcp:HeaderMismatch", ...
            "Mcp-Name header '%s' does not match body name '%s'.", ...
            headerName, bodyName);
    end
end
