function result = handleError(jrpc, ex)
%handleError Build a JSONRPC error response structure from a caught exception.
%
%   RESULT = handleError(REQUEST, JRPC, CODE, EX) constructs a JSONRPC
%   error response using the HTTP status CODE and the MException EX.
%   The jsonrpc version is taken from JRPC when available, and the request
%   id is taken from REQUEST when available.

% Copyright 2025-2026 The MathWorks, Inc.

    if ~isempty(jrpc) && isfield(jrpc,"jsonrpc")
        result.jsonrpc = jrpc.jsonrpc;
    else
        result.jsonrpc = "Unknown";
    end
    if isfield(jrpc,"id")
        result.id = jrpc.id;
    end
    % Rudimentary error location. May decide to add more detail.
    location = ex.stack(1);
    [~,file] = fileparts(location.file);
    msg = sprintf("%s:%d : %s", file, location.line, ex.message);
    % MPC error convention -- follow it or these errors will be ignored.
    r.isError = true;
    content.type = "text";
    content.text = msg;
    r.content = { content };
    result.result = r;
end
