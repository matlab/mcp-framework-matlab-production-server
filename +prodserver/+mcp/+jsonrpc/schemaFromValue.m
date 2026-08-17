function schema = schemaFromValue(value, typemap)
%schemaFromValue Generate a JSON Schema fragment from a live MATLAB value.
%   Recursively inspects the value and produces a struct representing the
%   JSON Schema that describes it.
%
%   schema = schemaFromValue(value)
%   schema = schemaFromValue(value, typemap)
%
%   typemap is a struct mapping MATLAB class names to JSON Schema type
%   strings (same format as build()'s opts.typemap). If omitted or empty,
%   uses the default mappings from jsonParameterType.

% Copyright 2026 The MathWorks, Inc.

    if nargin < 2 || isempty(typemap)
        typemap = struct();
    end

    if isstruct(value)
        schema = structSchema(value, typemap);
    elseif ischar(value) || isstring(value)
        schema.type = "string";
    elseif isnumeric(value)
        schema = numericSchema(value, typemap);
    elseif islogical(value)
        schema.type = "boolean";
    else
        schema.type = "object";
        schema.description = "MATLAB class: " + class(value);
    end
end

function schema = structSchema(value, typemap)
    if ~isscalar(value)
        schema.type = "array";
        schema.items.type = "object";
        return;
    end
    schema.type = "object";
    fields = string(fieldnames(value))';
    if isempty(fields)
        return;
    end
    schema.required = fields;
    for f = fields
        schema.properties.(f) = prodserver.mcp.jsonrpc.schemaFromValue(value.(f), typemap);
    end
end

function schema = numericSchema(value, typemap)
    import prodserver.mcp.jsonrpc.jsonParameterType

    jsonType = jsonParameterType(class(value), typemap);
    if jsonType == ""
        jsonType = "number";
    end

    sz = size(value);
    if isequal(sz, [1 1])
        schema.type = jsonType;
    else
        schema.type = "array";
        schema.items.type = jsonType;
    end
end
