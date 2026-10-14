function result = handleError(jrpc, ex)
%handleError Build a JSON-RPC error response from a protocol-level exception.
%
%   RESULT = handleError(JRPC, EX) constructs a JSON-RPC error object from
%   the MException EX. The request id is taken from JRPC when available.
%   Protocol errors (unknown method, bad/missing params, decode failures) are
%   reported as a JSON-RPC error object with a numeric error.code;
%   tool-EXECUTION errors are reported separately as isError results by the
%   tools/call handler, so they never reach here.

% Copyright 2025-2026 The MathWorks, Inc.

    import prodserver.mcp.MCPConstants

    % The response version is ours to state, not the client's to choose. A
    % request that named some other version never gets this far, and a
    % request too malformed to name one at all still needs a reply it can
    % parse.
    result.jsonrpc = MCPConstants.jrpcVersion;

    % JSON-RPC requires an id member on every error response. When the
    % request was too malformed to carry one, the id is null: jsonencode(NaN)
    % emits null, which is the wire form we need.
    if ~isempty(jrpc) && isstruct(jrpc) && isscalar(jrpc) && isfield(jrpc,"id")
        result.id = jrpc.id;
    else
        result.id = NaN;
    end

    result.error.code = prodserver.mcp.handler.internal.mapErrorCode(ex);
    % Rudimentary error location. May decide to add more detail.
    if ~isempty(ex.stack)
        location = ex.stack(1);
        [~,file] = fileparts(location.file);
        result.error.message = sprintf("%s:%d : %s", ...
            file, location.line, ex.message);
    else
        result.error.message = ex.message;
    end
end
