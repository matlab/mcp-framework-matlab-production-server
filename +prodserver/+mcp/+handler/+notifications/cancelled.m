function [result, httpCode, httpMsg, msgHeaders] = cancelled(jrpc)
%cancelled Handle MCP notifications/cancelled notification. Logs the
%   cancellation reason if provided.
%   Returns 202 Accepted with no response body per the MCP specification.

% Copyright 2025-2026 The MathWorks, Inc.

    httpCode = 202;
    httpMsg = 'Accepted';
    msgHeaders = {};

    % Log the reason -- if jrpc.params.reason exists.
    if isfield(jrpc,"params") && isfield(jrpc.params,"reason")
        if isfield(jrpc.params,"requestId")
            id = string(jrpc.params.requestId);
        else
            id = "(unknown)";
        end
        fprintf(1,"Request %s cancelled: %s\n",id, jrpc.params.reason);
    end

    result = [];
end
