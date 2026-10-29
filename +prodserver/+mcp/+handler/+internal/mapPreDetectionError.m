function [code, httpCode, httpMsg, data] = mapPreDetectionError(me, jrpc, request, attributed)
%mapPreDetectionError Map an exception raised before a protocol adapter
%   exists to a JSON-RPC error code and the HTTP status the specs mandate.
%
%   Parsing, envelope validation, protocol attribution and version
%   resolution all run before an adapter has been selected, so they cannot
%   use a protocol-specific mapper. This is their mapper.
%
%   Status keys off the exception IDENTIFIER, never the numeric code: -32602
%   is deliberately overloaded in 2026-07-28 (the missing-_meta family MUST
%   be 400, while unknown tool / unknown URI / invalid arguments
%   legitimately stay 200), so keying on the code trades one non-conformance
%   for three.
%
%   jrpc and request are accepted so the mandated `data` payloads can be
%   rebuilt without stashing state. The (me, jrpc) prefix matches the two
%   protocol mapErrorCode functions, so jsonrpc.errorResponse calls all three
%   the same way; handleError binds `request` and `attributed`, which only
%   this mapper has.
%
%   ATTRIBUTED is the adapter the request's SHAPE selected, or [] when
%   nothing was attributed. The failures split cleanly on that: parse,
%   envelope and media type all precede attribution, and
%   UnattributableRequest IS attribution failing, so those four are answered
%   here from revision-neutral values. HeaderMismatch and
%   UnsupportedProtocolVersion are raised only by ProtocolRegistry.resolve,
%   which always holds an attributed adapter, so they are answered by that
%   adapter's preDetectionError hook.
%
%   This file deliberately names no protocol revision. It used to reach into
%   v20260728.Constants for the two codes above, which was correct only
%   while exactly one revision carried per-request _meta; the hook asks the
%   revision the request was attributed to instead.

% Copyright 2026 The MathWorks, Inc.

    arguments
        me
        jrpc = []
        request = []
        attributed = []
    end

    import prodserver.mcp.MCPConstants

    data = [];
    id = string(me.identifier);

    % The attributed revision gets first refusal. It answers the failures
    % whose correct code depends on which revision the request declared, and
    % returns [] for everything else, which falls through to the neutral
    % arms below.
    if ~isempty(attributed)
        answer = attributed.preDetectionError(id, jrpc, request);
        if ~isempty(answer)
            code = answer.code;
            httpCode = answer.httpCode;
            httpMsg = answer.httpMsg;
            data = answer.data;
            return
        end
    end

    if startsWith(id, "prodserver:mcp:ParseError")
        code = MCPConstants.ErrorParseError;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(400);

    elseif startsWith(id, "prodserver:mcp:InvalidRequest")
        code = MCPConstants.ErrorInvalidRequest;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(400);

    elseif startsWith(id, "prodserver:mcp:UnsupportedMediaType")
        % No JSON-RPC code covers this; the body is reported with
        % InvalidRequest, but the status is HTTP's purpose-built 415.
        code = MCPConstants.ErrorInvalidRequest;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(415);

    elseif startsWith(id, "prodserver:mcp:InvalidServerURL")
        % The path names no server, so there is nothing here to speak MCP
        % at all. Neither spec covers it; 404 is HTTP's answer, and the body
        % is reported with InvalidRequest, as for 415.
        code = MCPConstants.ErrorInvalidRequest;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(404);

    elseif startsWith(id, "prodserver:mcp:UnattributableRequest")
        % No _meta, no initialize, no session header. We elect to answer as
        % though the request had meant to carry _meta and omitted it -- which
        % names no revision, as this file must not. (An engineering choice,
        % not a dual-spec mandate -- see design-decisions.md D43.)
        code = MCPConstants.ErrorInvalidParams;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(400);

    else
        code = MCPConstants.ErrorInternalError;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(500);
    end
end

