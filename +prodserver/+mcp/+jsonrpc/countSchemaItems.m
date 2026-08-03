function [minItems, maxItems] = countSchemaItems(schema)
%COUNTSCHEMAITEMS Recursively parse MCP tool parameter schema definition
%   [minItems, maxItems] = countSchemaItems(schema)
%
%   Parses a JSON Schema definition (as used by MCP tool parameters) and
%   determines the minimum and maximum number of items that may be passed
%   to that parameter.
%
%   Rules:
%   - Scalar types (string, number, integer, boolean, null): min=1, max=1
%   - Objects/structures: sum the values for all fields
%   - Arrays: multiply per-item counts by array bounds (minItems/maxItems)
%   - Unknown/unbounded: min=0, max=Inf
%
%   Input:
%       schema - A struct representing a JSON Schema definition, typically
%                with fields like 'type', 'properties', 'items', etc.
%
%   Output:
%       minItems - Minimum number of items (0 if unbounded below)
%       maxItems - Maximum number of items (Inf if unbounded above)
%
%   Example:
%       schema = struct('type', 'object', ...
%                       'properties', struct('name', struct('type', 'string'), ...
%                                            'age', struct('type', 'integer')), ...
%                       'required', {{'name'}});
%       [minVal, maxVal] = countSchemaItems(schema)
%       % Returns minVal=1, maxVal=2

    % Handle empty, missing, or invalid schema

% Copyright 2025-2026 The MathWorks, Inc.

    if nargin < 1 || isempty(schema)
        minItems = 0;
        maxItems = Inf;
        return;
    end

    % Handle non-struct input (e.g., true for additionalProperties)
    if ~isstruct(schema)
        % TODO: validate this count.
        minItems = 0;
        maxItems = Inf;
        return;
    end

    % If the schema is the wire-encoding wrapper, we must count the number
    % of items in the data array.
    if isfield(schema,"annotation") && ...
            contains(schema.annotation,"Invertible wire encoding wrapper for MCP Framework for MATLAB Production Server")
        schema = schema.properties.data;
    end

    % Get the type if specified
    if isfield(schema, 'type')
        schemaType = schema.type;
        % Handle type as cell array (e.g., ["string", "null"])
        if iscell(schemaType)
            schemaType = schemaType{1}; % Use first type for counting
        end
    else
        schemaType = '';
    end

    % Process based on schema type
    switch schemaType
        case {'string', 'number', 'integer', 'boolean', 'null'}
            % Scalar types always represent exactly one item
            minItems = 1;
            maxItems = 1;

        case 'object'
            % Structure: sum the values for all fields
            [minItems, maxItems] = processObjectSchema(schema);

        case 'array'
            % Array: compute based on array bounds and item schema
            [minItems, maxItems] = processArraySchema(schema);

        otherwise
            % No explicit type - check for composite schemas or infer
            [minItems, maxItems] = processCompositeOrUnknown(schema);
    end
end

%--------------------------------------------------------------------------
function [minItems, maxItems] = processObjectSchema(schema)
%PROCESSOBJECTSCHEMA Handle object/struct type schemas

    import prodserver.mcp.jsonrpc.countSchemaItems

    minItems = 0;
    maxItems = 0;

    % Get required fields list
    requiredFields = getRequiredFields(schema);

    % Process defined properties
    if isfield(schema, 'properties')
        props = schema.properties;
        propNames = fieldnames(props);

        for i = 1:length(propNames)
            propName = propNames{i};
            propSchema = props.(propName);

            % Recursively count items for this property
            [propMin, propMax] = countSchemaItems(propSchema);

            % Only add to minimum if the field is required
            if isFieldRequired(propName, requiredFields)
                minItems = minItems + propMin;
            end

            % Always add to maximum (optional fields could be present)
            maxItems = maxItems + propMax;
        end
    end

    % Handle additionalProperties - if allowed, max becomes unbounded
    if hasUnboundedAdditionalProperties(schema)
        maxItems = Inf;
    end
end

%--------------------------------------------------------------------------
function [minItems, maxItems] = processArraySchema(schema)
%PROCESSARRAYSCHEMA Handle array type schemas

    import prodserver.mcp.jsonrpc.countSchemaItems

    % Get array length bounds
    if isfield(schema, 'minItems')
        arrayMin = schema.minItems;
    else
        arrayMin = 0; % Arrays can be empty by default
    end

    if isfield(schema, 'maxItems')
        arrayMax = schema.maxItems;
    else
        arrayMax = Inf; % No upper limit by default
    end

    % Get the schema for array items
    if isfield(schema, 'items')
        itemsSchema = schema.items;

        % Handle tuple validation (items as array of schemas)
        if iscell(itemsSchema)
            [minItems, maxItems] = processTupleItems(itemsSchema, schema);
            return;
        elseif prodserver.mcp.validation.isPrimitiveType(itemsSchema.type)
            % An array of primitive types -- the size is determined by the
            % size of the array, since each element is a scalar.
            itemMin = 1; 
            itemMax = 1;
        else
            % All items share the same schema
            [itemMin, itemMax] = countSchemaItems(itemsSchema);
        end
    else
        % No items schema - each element counts as 1
        itemMin = 1;
        itemMax = 1;
    end

    % Compute total items: array length * items per element -- note Inf *
    % <anything> is still Inf, so no need to test for Inf explicitly.
    minItems = arrayMin * itemMin;
    maxItems = arrayMax * itemMax;
end

%--------------------------------------------------------------------------
function [minItems, maxItems] = processTupleItems(itemsSchemas, schema)
%PROCESSTUPLEITEMS Handle tuple-style array validation (items as array)

    import prodserver.mcp.jsonrpc.countSchemaItems

    minItems = 0;
    maxItems = 0;

    % Process each positional item schema
    for i = 1:length(itemsSchemas)
        [itemMin, itemMax] = countSchemaItems(itemsSchemas{i});
        minItems = minItems + itemMin;
        maxItems = maxItems + itemMax;
    end

    % Check for additionalItems (items beyond the tuple)
    if isfield(schema, 'additionalItems')
        addItems = schema.additionalItems;
        if islogical(addItems) && addItems
            % Additional items allowed with no schema - unbounded
            maxItems = Inf;
        elseif isstruct(addItems)
            % Additional items allowed with schema - unbounded
            maxItems = Inf;
        end
        % If additionalItems is false, max stays as computed
    end
end

%--------------------------------------------------------------------------
function [minItems, maxItems] = processCompositeOrUnknown(schema)
%PROCESSCOMPOSITEUNKNOWN Handle composite schemas (oneOf, anyOf, allOf) or unknown

    % Check for oneOf (exactly one must match)
    if isfield(schema, 'oneOf')
        [minItems, maxItems] = processUnionSchemas(schema.oneOf);
        return;
    end

    % Check for anyOf (at least one must match)
    if isfield(schema, 'anyOf')
        [minItems, maxItems] = processUnionSchemas(schema.anyOf);
        return;
    end

    % Check for allOf (all must match - intersection)
    if isfield(schema, 'allOf')
        [minItems, maxItems] = processAllOfSchemas(schema.allOf);
        return;
    end

    % Check if this looks like an object (has properties but no type)
    if isfield(schema, 'properties')
        [minItems, maxItems] = processObjectSchema(schema);
        return;
    end

    % Check if this looks like an array (has items but no type)
    if isfield(schema, 'items')
        schema.type = 'array';
        [minItems, maxItems] = processArraySchema(schema);
        return;
    end

    % Truly unknown schema - no constraints
    minItems = 0;
    maxItems = Inf;
end

%--------------------------------------------------------------------------
function [minItems, maxItems] = processUnionSchemas(schemas)
%PROCESSUNIONSCHEMAS Handle oneOf/anyOf (union of possible schemas)
%   Takes min of mins and max of maxes across all options

    import prodserver.mcp.jsonrpc.countSchemaItems

    if isempty(schemas)
        minItems = 0;
        maxItems = Inf;
        return;
    end

    % Convert to cell if needed
    if ~iscell(schemas)
        schemas = {schemas};
    end

    minItems = Inf;
    maxItems = 0;

    for i = 1:length(schemas)
        [optMin, optMax] = countSchemaItems(schemas{i});
        minItems = min(minItems, optMin);
        maxItems = max(maxItems, optMax);
    end

    % Handle edge case where minItems stayed at Inf. Maybe the > 0 check
    % defends this code against: maxItems: -Inf? It's cheap, and almost
    % always short-circuited, so leave it in.
    if isinf(minItems) && minItems > 0
        minItems = 0;
    end
end

%--------------------------------------------------------------------------
function [minItems, maxItems] = processAllOfSchemas(schemas)
%PROCESSALLOFSCHEMAS Handle allOf (all schemas must be satisfied)
%   For counting purposes, we take the most restrictive interpretation
 
    import prodserver.mcp.jsonrpc.countSchemaItems

    if isempty(schemas)
        minItems = 0;
        maxItems = Inf;
        return;
    end

    % Convert to cell if needed
    if ~iscell(schemas)
        schemas = {schemas};
    end

    % For allOf, the data must satisfy all schemas simultaneously
    % We accumulate properties from all sub-schemas
    minItems = 0;
    maxItems = 0;
    hasUnbounded = false;

    for i = 1:length(schemas)
        [subMin, subMax] = countSchemaItems(schemas{i});

        % Take maximum of minimums (most restrictive)
        minItems = max(minItems, subMin);

        % Accumulate maximums (properties combine)
        if isinf(subMax)
            hasUnbounded = true;
        else
            maxItems = max(maxItems, subMax);
        end
    end

    if hasUnbounded
        maxItems = Inf;
    end
end

%--------------------------------------------------------------------------
function requiredFields = getRequiredFields(schema)
%GETREQUIREDFIELDS Extract required fields list from schema

    if isfield(schema, 'required')
        req = schema.required;
        if iscell(req)
            requiredFields = req;
        elseif ischar(req) || isstring(req)
            requiredFields = {char(req)};
        else
            requiredFields = {};
        end
    else
        requiredFields = {};
    end
end

%--------------------------------------------------------------------------
function tf = isFieldRequired(fieldName, requiredFields)
%ISFIELDREQUIRED Check if a field is in the required list

    if isempty(requiredFields)
        tf = false;
        return;
    end

    tf = any(strcmp(fieldName, requiredFields));
end

%--------------------------------------------------------------------------
function tf = hasUnboundedAdditionalProperties(schema)
%HASUNBOUNDEDADDITIONALPROPERTIES Check if schema allows unbounded additional properties

    tf = false;

    if ~isfield(schema, 'additionalProperties')
        % By default in JSON Schema, additionalProperties is true
        % But for MCP schemas, we typically assume it's restricted
        return;
    end

    addProps = schema.additionalProperties;

    if islogical(addProps) && addProps
        tf = true;
    elseif isstruct(addProps)
        % Schema for additional properties exists - they're allowed
        tf = true;
    end
end
