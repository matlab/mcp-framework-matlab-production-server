function tf = isJsonRpcError(data)
%isJsonRpcError True if DATA is a JSON-RPC response carrying an error object.
%   Only a scalar struct whose 'error' member is itself a struct with 'code'
%   and 'message' counts. Anything else -- a string, a number, an array --
%   is a body that merely happens to have an 'error' key, and must not be
%   dereferenced as if it were an error object (ND6).

% Copyright 2026 The MathWorks, Inc.

    tf = isstruct(data) && isscalar(data) && isfield(data, "error") && ...
        isstruct(data.error) && isscalar(data.error) && ...
        isfield(data.error, "code") && isfield(data.error, "message");
end
