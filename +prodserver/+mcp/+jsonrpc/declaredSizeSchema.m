function schema = declaredSizeSchema(schema, validationSize, scalarType)
%declaredSizeSchema Shape a parameter's schema by its declared size.
%   schema = declaredSizeSchema(schema, validationSize, scalarType) applies
%   the size an arguments block declares, VALIDATIONSIZE, to SCHEMA:
%
%     (1,1)        Not an array: items, minItems and maxItems go, and an
%                  array (or untyped) schema takes the type SCALARTYPE,
%                  unless SCALARTYPE is "".
%     more         An array, even if every example passed a scalar, of the
%                  schemas SCHEMA describes. A fixed size is an exact
%                  count, so it is both minItems and maxItems.
%
%   An empty VALIDATIONSIZE leaves SCHEMA as it is. Both schema paths use
%   this: the declared path for its generated schema, the example path for
%   what it observed. A text parameter (see isCharText) is not an array,
%   whatever its size; the callers don't pass one.

% Copyright 2026 The MathWorks, Inc.

    if isempty(validationSize)
        return
    end
    n = prodserver.mcp.jsonrpc.sizeFromValidation(validationSize);
    if n == 1
        schema = rmfield(schema, intersect(fieldnames(schema), ...
            {'items', 'minItems', 'maxItems'}));
        if strlength(scalarType) > 0 && ...
                (~isfield(schema, 'type') || strcmpi(schema.type, "array"))
            schema.type = scalarType;
        end
    elseif n > 1
        schema = asArraySchema(schema);
        if ~isinf(n)
            schema.minItems = n;
            schema.maxItems = n;
        end
    end
end

function schema = asArraySchema(schema)
% Turn a schema into an array schema. Array schemas, or array alternatives
% of an anyOf, contribute their item schemas; scalar ones contribute
% themselves.
    if isfield(schema, 'anyOf')
        fragments = prodserver.mcp.jsonrpc.schemaAlternatives(schema);
    else
        fragments = {schema};
    end
    items = {};
    for k = 1:numel(fragments)
        f = fragments{k};
        if isfield(f, 'type') && strcmpi(f.type, "array")
            if isfield(f, 'items')
                f = f.items;
            else
                f = struct();
            end
        end
        items{end+1} = f; %#ok<AGROW>
    end
    schema = struct('type', "array", 'items', ...
        prodserver.mcp.jsonrpc.anyOfSchema(items));
end
