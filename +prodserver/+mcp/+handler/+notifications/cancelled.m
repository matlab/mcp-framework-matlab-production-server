function [result, httpCode, httpMsg, msgHeaders] = cancelled(jrpc)
%cancelled Handle MCP notifications/cancelled notification. Logs the
%   cancellation reason if provided.
%   Returns 202 Accepted with no response body per the MCP specification.

% Copyright 2025-2026 The MathWorks, Inc.

    [httpCode, httpMsg] = prodserver.mcp.handler.internal.httpStatus(202);
    msgHeaders = {};

    import prodserver.mcp.internal.hasField

    % Log the reason -- if jrpc.params.reason exists. Either member may be
    % of any type a sender cares to put there (XD10); only scalar text or a
    % scalar number is printed as itself.
    if hasField(jrpc, "params.reason")
        id = "(unknown)";
        if hasField(jrpc, "params.requestId")
            id = scalarText(jrpc.params.requestId, id);
        end
        reason = scalarText(jrpc.params.reason, "(unreadable reason)");
        fprintf(1,"Request %s cancelled: %s\n", id, reason);
    end

    result = [];
end

function t = scalarText(v, fallback)
%scalarText V as a single string if it is scalar text or a real scalar
%   number, else FALLBACK.
    t = fallback;
    if (ischar(v) && (isrow(v) || isempty(v))) || ...
            (isstring(v) && isscalar(v) && ~ismissing(v)) || ...
            (isnumeric(v) && isreal(v) && isscalar(v))
        t = string(v);
    end
end
