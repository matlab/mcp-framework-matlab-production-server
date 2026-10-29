function [result, httpCode, httpMsg] = handleError(jrpc, ex, request, attributed)
%handleError Build a JSON-RPC 2.0 error response for pre-detection failures.
%   Used when no protocol adapter could be matched, so the protocol-specific
%   status mapping is unavailable. The code and status come from
%   mapPreDetectionError, which recognizes the failures that happen before
%   an adapter exists (parse, envelope, media type, protocol attribution,
%   version resolution); anything it does not recognize is a genuine
%   internal failure and maps to HTTP 500.
%
%   The envelope itself is jsonrpc.errorResponse, the same one the adapters
%   use. All that is protocol-specific about an error response is the mapper.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        jrpc
        ex
        request = []
        attributed = []
    end

    % request and attributed are bound here rather than passed through
    % errorResponse: they are the two inputs the post-detection mappers never
    % have, because formatError is handed the body and not the request, and by
    % the time it runs the adapter is no longer merely attributed. attributed
    % is the adapter the request's shape selected even though resolution then
    % failed -- mapPreDetectionError asks it for the codes whose correctness
    % depends on which revision the request declared.
    mapper = @(me, body) ...
        prodserver.mcp.handler.internal.mapPreDetectionError( ...
            me, body, request, attributed);

    [result, httpCode, httpMsg] = ...
        prodserver.mcp.jsonrpc.errorResponse(ex, jrpc, mapper);
end
