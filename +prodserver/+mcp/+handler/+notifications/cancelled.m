function [result, httpCode, httpMsg, msgHeaders] = cancelled(jrpc)
%cancelled Handle MCP notifications/cancelled notification. Logs every
%   cancellation as prodserver.mcp.logging.Event.RequestCancelled, at
%   Information, with the request id and the reason; MCP makes the reason
%   optional, and a cancellation without one is logged with "(no reason)".
%   Returns 202 Accepted with no response body per the MCP specification.

% Copyright 2025-2026 The MathWorks, Inc.

    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(202);
    msgHeaders = {};

    import prodserver.mcp.internal.hasField

    % Either member may be of any type a sender cares to put there (XD10);
    % only scalar text or a scalar number is printed as itself, bounded by
    % echo.
    id = "(unknown)";
    if hasField(jrpc, "params.requestId")
        id = scalarText(jrpc.params.requestId, id);
    end
    reason = "(no reason)";
    if hasField(jrpc, "params.reason")
        reason = scalarText(jrpc.params.reason, "(unreadable reason)");
    end
    prodserver.mcp.logging.Log.instance().log( ...
        prodserver.mcp.logging.Level.Information, ...
        prodserver.mcp.logging.Event.RequestCancelled, ...
        "Request %s cancelled: %s", id, reason);

    result = [];
end

function t = scalarText(v, fallback)
%scalarText V, the caller's, bounded and quoted by echo if it is scalar
%   text or a real scalar number, else FALLBACK, as it is.
    t = fallback;
    if prodserver.mcp.validation.isTextScalar(v) || ...
            (isnumeric(v) && isreal(v) && isscalar(v))
        t = prodserver.mcp.protocol.echo(string(v));
    end
end
