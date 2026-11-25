function tf = isRequestId(id)
%isRequestId True if ID, as jsondecode delivers a request's id member, is
%   one MCP allows: a string, empty included, or a whole number. Not null,
%   which MCP forbids though JSON-RPC allows it, nor an object, array,
%   boolean or fractional number. JSON-RPC 2.0 allows any number, but MCP
%   requires a string or an integer, in every revision.
%
%   jsondecode makes a string char (empty for ""), a number double, null
%   [], a boolean logical, an object a struct and an array an array.
%
%   validateEnvelope rejects a request whose id isn't one; responseId
%   echoes only one, and answers null otherwise.

% Copyright 2026 The MathWorks, Inc.

    tf = (ischar(id) && (isrow(id) || isequal(size(id), [0 0]))) || ...
        (isstring(id) && isscalar(id) && ~ismissing(id)) || ...
        (isnumeric(id) && isscalar(id) && isreal(id) && isfinite(id) && ...
            id == round(id));
end
