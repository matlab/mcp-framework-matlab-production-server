function schema = unstackSchemaLists(schema)
%unstackSchemaLists Give each member of a decoded schema's lists a cell.
%   schema = unstackSchemaLists(schema) replaces the value of every enum
%   and examples keyword in SCHEMA, a JSON Schema as jsondecode gives it,
%   at any depth, with a cell holding one member of the list each (see
%   unstackDecodedArray). jsonencode then writes them as JSON arrays, as
%   JSON Schema requires, even with one member, and the validator compares
%   an argument with each member, not with the whole list.
%
%   The values of default and const are data, not schemas, and are left
%   as they are, as are the names of properties: a property named enum is
%   not the keyword.

% Copyright 2026 The MathWorks, Inc.

    if isstruct(schema)
        for k = 1:numel(schema)
            schema(k) = unstackOne(schema(k));
        end
    elseif iscell(schema)
        for k = 1:numel(schema)
            schema{k} = prodserver.mcp.jsonrpc.unstackSchemaLists(schema{k});
        end
    end
end

function s = unstackOne(s)
% S is one schema: an object whose fields are keywords.

    % Keywords whose value maps names to schemas, as jsondecode names them.
    named = ["properties" "patternProperties" "dependentSchemas" ...
        "definitions" "x_defs"];

    for f = string(fieldnames(s))'
        if ismember(f, ["enum" "examples"])
            s.(f) = prodserver.mcp.jsonrpc.unstackDecodedArray(s.(f));
        elseif ismember(f, ["default" "const"])
            continue
        elseif ismember(f, named) && isstruct(s.(f)) && isscalar(s.(f))
            for name = string(fieldnames(s.(f)))'
                s.(f).(name) = prodserver.mcp.jsonrpc.unstackSchemaLists( ...
                    s.(f).(name));
            end
        else
            % items, anyOf, not, and the like: a schema or a list of them.
            % Values of other keywords hold no structs or cells.
            s.(f) = prodserver.mcp.jsonrpc.unstackSchemaLists(s.(f));
        end
    end
end
