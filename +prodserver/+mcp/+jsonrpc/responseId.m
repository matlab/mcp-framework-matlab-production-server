function id = responseId(jrpc)
%responseId JSON-RPC 2.0 id member for a response built from a request.
%   JSON-RPC 2.0 section 5 requires every Response object to carry an id
%   member: the request's id when it can be determined, and null when it
%   cannot -- a parse error, or an envelope too malformed to read an id
%   from. "Null" means present-and-null, not absent.
%
%   Returns NaN for the null case because jsonencode renders NaN as null
%   under the default ConvertInfAndNaN=true. Do NOT substitute []: an id of
%   [] encodes as [], and after encoding it is indistinguishable from a
%   legitimately empty array such as tools: [] or content: [], so a blanket
%   []-to-null rule in encodeMessage would corrupt empty result arrays.
%
%   isscalar is load-bearing, not defensive. A JSON-RPC batch body decodes
%   to a struct ARRAY, and on an array jrpc.id expands to a comma-separated
%   list, so isempty(jrpc.id) raises MATLAB:maxrhs. This runs on the error
%   path -- validateEnvelope has already rejected the batch -- so a crash
%   here escapes mcpHandler's own catch and reaches the server as a raw
%   MATLAB error instead of the -32600 that was already decided on. An
%   unreadable envelope is exactly the null-id case this function exists for.

% Copyright 2026 The MathWorks, Inc.

    if ~isempty(jrpc) && isstruct(jrpc) && isscalar(jrpc) && ...
            isfield(jrpc, "id") && ~isempty(jrpc.id)
        id = jrpc.id;
    else
        id = NaN;
    end
end
