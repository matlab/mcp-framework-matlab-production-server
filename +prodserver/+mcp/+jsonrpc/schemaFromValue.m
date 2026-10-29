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
%
%   A value of any other class gets a tag instead of a schema: the fields
%   Constants.ClassTag and Constants.ScalarTag. Whether the class can
%   travel at all depends on the wire encoding, which this function doesn't
%   know, so the caller must resolve every tag. A cell whose elements
%   include tags lists their schemas in Constants.ElementsTag, so they can
%   be checked too.

% Copyright 2026 The MathWorks, Inc.

    if nargin < 2 || isempty(typemap)
        typemap = struct();
    end

    if isstruct(value)
        schema = structSchema(value, typemap);
    elseif ischar(value)
        % A char row vector, or matrix, is text.
        schema.type = prodserver.mcp.jsonrpc.jsonParameterType("char", typemap);
    elseif isnumeric(value) || islogical(value) || isstring(value)
        % A scalar, or an array of them (a string array is an array of
        % strings).
        schema = primitiveSchema(value, typemap);
    elseif iscell(value)
        schema = cellSchema(value, typemap);
    elseif isfield(typemap, class(value))
        schema.type = typemap.(class(value));
    else
        C = prodserver.mcp.internal.Constants;
        schema.(C.ClassTag) = string(class(value));
        schema.(C.ScalarTag) = isscalar(value);
    end
end

function schema = cellSchema(value, typemap)
    % The elements may differ in type, so the items aren't described. But
    % a tagged element must still reach the caller.
    schema.type = "array";
    tagged = {};
    for k = 1:numel(value)
        s = prodserver.mcp.jsonrpc.schemaFromValue(value{k}, typemap);
        if hasTag(s)
            tagged{end+1} = s; %#ok<AGROW>
        end
    end
    if ~isempty(tagged)
        schema.(prodserver.mcp.internal.Constants.ElementsTag) = tagged;
    end
end

function tf = hasTag(s)
    C = prodserver.mcp.internal.Constants;
    tf = false;
    if isstruct(s)
        if isfield(s, C.ClassTag) || isfield(s, C.ElementsTag)
            tf = true;
            return
        end
        f = fieldnames(s);
        for k = 1:numel(f)
            if hasTag(s.(f{k}))
                tf = true;
                return
            end
        end
    elseif iscell(s)
        tf = any(cellfun(@hasTag, s));
    end
end

function schema = structSchema(value, typemap)
    if ~isscalar(value)
        % Describe the elements, so the fields survive. Elements share
        % field names but may differ in field types.
        schema.type = "array";
        items = cell(1, numel(value));
        for k = 1:numel(value)
            items{k} = structSchema(value(k), typemap);
        end
        if isempty(items)
            schema.items.type = "object";
        else
            schema.items = prodserver.mcp.jsonrpc.anyOfSchema(items);
        end
        return;
    end
    schema.type = "object";
    fields = string(fieldnames(value))';
    if isempty(fields)
        return;
    end
    % A cell, so that jsonencode writes an array even for one field: JSON
    % Schema requires one, and a 1x1 string array would be a bare string.
    schema.required = cellstr(fields);
    for f = fields
        schema.properties.(f) = prodserver.mcp.jsonrpc.schemaFromValue(value.(f), typemap);
    end
end

function schema = primitiveSchema(value, typemap)
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
