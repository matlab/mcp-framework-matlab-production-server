function [code, httpCode, httpMsg, data] = mapErrorCode(me, jrpc)
%mapErrorCode Map a MATLAB exception identifier to a JSON-RPC error code AND
%   the HTTP status the spec mandates, for MCP v2026-07-28.
%
%   Status MUST key off the exception IDENTIFIER, never the numeric code.
%   -32602 is deliberately overloaded: the missing-_meta family MUST be
%   HTTP 400, while unknown tool / unknown resource URI / invalid arguments
%   are spec-silent and legitimately stay 200. Switching on the code moves
%   all of them to 400 and trades one non-conformance for three.
%
%   jrpc is the request body, needed only to name the version a rejected
%   request asked for. Every mapper takes it so that jsonrpc.errorResponse can
%   call them all the same way.
%
%   ParseError and InvalidRequest are deliberately absent: those failures
%   happen before an adapter exists, and belong to
%   handler.internal.mapPreDetectionError.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    C = prodserver.mcp.protocol.v20260728.Constants;

    data = [];
    id = string(me.identifier);

    if startsWith(id, "prodserver:mcp:MethodNotFound")
        % Spec: an unimplemented method MUST be 404 with code -32601.
        code = MCPConstants.ErrorMethodNotFound;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(404);

    elseif startsWith(id, "prodserver:mcp:HeaderMismatch")
        % Spec: header/body mismatch, or a missing/malformed required
        % header, MUST be 400 with code -32020.
        code = C.ErrorHeaderMismatch;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(400);

    elseif startsWith(id, "prodserver:mcp:UnsupportedProtocolVersion")
        % Not reachable today: ProtocolRegistry.lookup is the only raiser and
        % it runs before an adapter exists, so mapPreDetectionError answers
        % this in practice. The arm stays because the alternative to a wrong
        % answer here is a silent 500, and it shares the payload builder so it
        % cannot drift into being a differently wrong answer.
        code = C.ErrorUnsupportedVersion;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(400);
        % Only jrpc is available here, which is enough: after an adapter
        % has been chosen, the only version a request can still be rejected
        % for is the one in its _meta.
        data = prodserver.mcp.protocol.unsupportedVersionData( ...
            prodserver.mcp.protocol.v20260728.metaVersion(jrpc));

    elseif startsWith(id, "prodserver:mcp:MissingMeta") || ...
            startsWith(id, "prodserver:mcp:MissingProtocolVersion") || ...
            startsWith(id, "prodserver:mcp:MissingCapabilities")
        % The missing-_meta family: 2026-07-28 makes a missing required
        % _meta field a MUST-400, reported as Invalid Params.
        code = MCPConstants.ErrorInvalidParams;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(400);

    elseif startsWith(id, "prodserver:mcp:ResourceNotFound") || ...
            prodserver.mcp.protocol.isClientMistake(me)
        % ResourceNotFound joins the caller's-mistake set only here:
        % 2026-07-28 folded it into Invalid Params (changelog minor #6) and
        % MUST NOT emit -32002, where 2025-06-18 has a dedicated code for it.
        % The status is spec-silent, so it stays in the body over HTTP 200 --
        % the same shape as both specs' unknown-tool example.
        code = MCPConstants.ErrorInvalidParams;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(200);

    else
        code = MCPConstants.ErrorInternalError;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(500);
    end
end

