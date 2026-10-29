function schema = anyOfSchema(schemas)
%anyOfSchema One schema accepting any of several.
%   schema = anyOfSchema(schemas) is the one schema in cell array SCHEMAS
%   once duplicates are removed (see uniqueSchemas), or an anyOf of the
%   distinct ones. With no schemas at all it is struct(): any value.

% Copyright 2026 The MathWorks, Inc.

    u = prodserver.mcp.jsonrpc.uniqueSchemas(schemas);
    if isempty(u)
        schema = struct();
    elseif isscalar(u)
        schema = u{1};
    else
        schema = struct('anyOf', {u});
    end
end
