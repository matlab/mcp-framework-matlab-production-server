function [code, httpCode, httpMsg, data] = mapErrorCode(me, ~)
%mapErrorCode Map a MATLAB exception identifier to a JSON-RPC error code AND
%   the HTTP status the spec mandates, for MCP v2025-06-18.
%
%   Status keys off the exception IDENTIFIER, not the numeric code. Under
%   Streamable HTTP a JSON-RPC error is normally carried in the body over
%   HTTP 200 -- the transport succeeded -- so only a genuine internal error
%   is an HTTP 500.
%
%   The unused second argument is the request body. Every mapper takes it so
%   that jsonrpc.errorResponse can call them all the same way; this revision
%   has no error whose payload depends on what the request said.
%
%   ParseError and InvalidRequest are deliberately absent: those failures
%   happen before an adapter exists, and belong to
%   handler.internal.mapPreDetectionError.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    data = [];
    id = string(me.identifier);

    if startsWith(id, "prodserver:mcp:MethodNotFound")
        % 2025-06-18 carries method-not-found in the body over HTTP 200.
        code = MCPConstants.ErrorMethodNotFound;
        [httpCode, httpMsg] = ok();

    elseif startsWith(id, "prodserver:mcp:ResourceNotFound")
        % 2025-06-18 reports a missing resource with the dedicated
        % resource-not-found code. (2026-07-28 MUST NOT emit -32002.)
        code = prodserver.mcp.protocol.v20250618.Constants.ErrorResourceNotFound;
        [httpCode, httpMsg] = ok();

    elseif prodserver.mcp.protocol.isClientMistake(me)
        % The caller got it wrong, so the transport did not: Invalid Params
        % in the body over HTTP 200.
        code = MCPConstants.ErrorInvalidParams;
        [httpCode, httpMsg] = ok();

    else
        code = MCPConstants.ErrorInternalError;
        [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(500);
    end
end

function [httpCode, httpMsg] = ok()
    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(200);
end
