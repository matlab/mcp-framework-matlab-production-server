function [result, httpCode, httpMsg] = errorResponse(me, jrpc, mapper)
%errorResponse The JSON-RPC 2.0 error envelope, assembled in one place.
%   mapper is a function handle called as mapper(me, jrpc). It owns everything
%   protocol-specific: the error code, the HTTP status its spec mandates, and
%   any mandated `data` payload. This function owns only the envelope.
%
%   Three mappers share this: the two protocol mapErrorCode functions and
%   handler.internal.mapPreDetectionError, which serves the stages that run
%   before an adapter has been selected. They all answer the same question for
%   different parts of the pipeline, so they take the same arguments and are
%   called the same way -- a mapper that does not need jrpc ignores it.
%
%   Having one envelope matters more than it looks. The JSON-RPC 2.0 section 5
%   requirement that `id` be present on every response, the file:line prefix on
%   the message, and the rule that `data` is omitted rather than sent empty are
%   each a single line that is easy to write differently the second time.

% Copyright 2026 The MathWorks, Inc.

    result.jsonrpc = prodserver.mcp.MCPConstants.jrpcVersion;

    % JSON-RPC 2.0 section 5: present on every response, null when it cannot
    % be determined. Unconditional -- an `isfield` guard with no else omits
    % the member entirely.
    result.id = prodserver.mcp.jsonrpc.responseId(jrpc);

    [code, httpCode, httpMsg, data] = mapper(me, jrpc);

    result.error.code = code;
    if ~isempty(me.stack)
        location = me.stack(1);
        [~, file] = fileparts(location.file);
        result.error.message = sprintf("%s:%d : %s", ...
            file, location.line, me.message);
    else
        result.error.message = me.message;
    end
    if ~isempty(data)
        result.error.data = data;
    end
end
