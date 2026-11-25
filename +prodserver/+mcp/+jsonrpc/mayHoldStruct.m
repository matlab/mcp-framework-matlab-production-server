function tf = mayHoldStruct(schema, names)
%mayHoldStruct Whether a schema may hold a struct with given fields.
%   tf = mayHoldStruct(schema, names) is true if a struct whose fields are
%   NAMES, a string array, may satisfy SCHEMA, an object's schema or, for
%   an array, its items': the struct has every property SCHEMA requires,
%   and no other property where SCHEMA's additionalProperties is false.
%   Its fields' values aren't checked. A schema whose type is not an
%   object's, such as a number's or an array of numbers', holds none.
%
%   Where a schema lists alternatives for a struct, plainJSONValue writes
%   it under one that may hold it, and objectFieldSchemas gives its fields
%   by those, as decodeJSONValues reads them back: under anyOf [{a, b
%   required}, {a: array}], struct('a',7) is the second's, {"a":[7]}.

% Copyright 2026 The MathWorks, Inc.

    tf = false;
    if ~isstruct(schema) || ~isscalar(schema)
        return
    end
    if isfield(schema, 'type') && all(string(schema.type) == "array")
        if ~isfield(schema, 'items') || ~isstruct(schema.items) || ...
                ~isscalar(schema.items)
            tf = true;
            return
        end
        schema = schema.items;
    end
    if ~isstruct(schema) || ~isscalar(schema) || ...
            (isfield(schema, 'type') && ~any(string(schema.type) == "object"))
        % A type that is no object's: a number's, an array of strings'.
        return
    end
    names = string(names);
    try
        required = prodserver.mcp.internal.requiredNames(schema);
    catch
        required = string.empty;
    end
    tf = all(ismember(required, names));
    if tf && isfield(schema, 'additionalProperties') && ...
            isequal(schema.additionalProperties, false)
        known = string.empty;
        if isfield(schema, 'properties') && isstruct(schema.properties)
            known = string(fieldnames(schema.properties));
        end
        tf = all(ismember(names, known));
    end
end
