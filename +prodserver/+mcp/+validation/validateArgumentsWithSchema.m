function validateArgumentsWithSchema(schema, names, values)
%VALIDATEARGUMENTSWITHSCHEMA Validate MATLAB arguments against a JSON-RPC schema
%   validateArgumentsWithSchema(SCHEMA, NAMES, VALUES) validates each value
%   in the cell array VALUES against the corresponding schema definition.
%   NAMES is a string array of argument names where NAMES(n) corresponds to
%   VALUES{n}. An error is issued identifying the first argument that fails
%   validation, including the argument name and a description of the type 
%   mismatch.
%
%   SCHEMA can be either an input schema or output schema from a JSON-RPC
%   method definition. The function handles nested types (structs, cell arrays)
%   recursively, but validates user-defined classes only by type name using 
%   isa().

% Copyright 2026 The MathWorks, Inc.

    arguments
        schema (1,1) struct
        names (1,:) string
        values (1,:) cell
    end

    if numel(names) ~= numel(values) 
        error("prodserver:mcp:InputSizeMismatch",...
    "Number of variable names (%d) must match number of values (%d)", ...
        numel(names), numel(values));
    end

    % Extract parameter schemas from the schema structure
    paramSchemas = extractParameterSchemas(schema, names);

    if isempty(paramSchemas) || any(cellfun('isempty',paramSchemas))
        if ~isempty(paramSchemas)
            notFound = cellfun('isempty',paramSchemas);
            names = names(notFound);
        end
        error("prodserver:mcp:NoSchemaForParameters", ...
            "No schema found for parameter(s) '%s'.", strjoin(names,","));
    end

    % Validate each argument
    for i = 1:numel(values)
        argName = names(i);
        argValue = values{i};

        if i <= numel(paramSchemas) && ~isempty(paramSchemas{i})
            paramSchema = paramSchemas{i};
            [isValid, errMsg] = validateValue(argValue, paramSchema, argName);

            if ~isValid
                error('prodserver:mcp:SchemaValidationFailed', ...
                    'Argument ''%s'' failed validation: %s', argName, errMsg);
            end
        end
    end
end

%% Local Functions

function paramSchemas = extractParameterSchemas(schema, names)
%EXTRACTPARAMETERSCHEMAS Extract individual parameter schemas from a JSON-RPC schema
    paramSchemas = cell(1, numel(names));

    % Handle different schema formats
    if isfield(schema, 'properties')
        % Object-style schema with properties
        props = schema.properties;
        for i = 1:numel(names)
            name = names(i);
            if isfield(props, name)
                paramSchemas{i} = props.(name);
            end
        end
    elseif isfield(schema, 'items')
        % Array-style schema (positional parameters)
        items = schema.items;
        if iscell(items)
            % Tuple validation - each position has its own schema
            for i = 1:min(numel(names), numel(items))
                paramSchemas{i} = items{i};
            end
        elseif isstruct(items)
            % All items share the same schema
            for i = 1:numel(names)
                paramSchemas{i} = items;
            end
        end
    elseif isfield(schema, 'params')
        % JSON-RPC style with params array
        params = schema.params;
        if isstruct(params) && isfield(params, 'properties')
            paramSchemas = extractParameterSchemas(params, names);
        elseif iscell(params)
            for i = 1:min(numel(names), numel(params))
                paramSchemas{i} = params{i};
            end
        end
    elseif isfield(schema, 'result')
        % Output schema - validate against result schema
        paramSchemas = extractParameterSchemas(schema.result, names);
    end
end

function [isValid, errMsg] = validateValue(value, schema, path)
%VALIDATEVALUE Recursively validate a value against a schema
    isValid = true;
    errMsg = '';

    if isempty(schema) || ~isstruct(schema)
        return;
    end

    % Handle schema references
    if isfield(schema, 'x]ref') || isfield(schema, 'ref')
        refField = 'ref';
        if isfield(schema, 'x]ref')
            refField = 'x]ref';
        end
        className = extractClassName(schema.(refField));
        if ~isempty(className) && ~isa(value, className)
            isValid = false;
            errMsg = sprintf('expected class ''%s'', got ''%s''', className, class(value));
        end
        return;
    end

    % Handle custom class type specification
    if isfield(schema, 'matlabClass')
        expectedClass = schema.matlabClass;
        if ~isa(value, expectedClass)
            isValid = false;
            errMsg = sprintf('expected class ''%s'', got ''%s''', expectedClass, class(value));
        end
        return;
    end

    % Handle anyOf, oneOf, allOf combinators
    if isfield(schema, 'anyOf')
        [isValid, errMsg] = validateAnyOf(value, schema.anyOf, path);
        return;
    end
    if isfield(schema, 'oneOf')
        [isValid, errMsg] = validateOneOf(value, schema.oneOf, path);
        return;
    end
    if isfield(schema, 'allOf')
        [isValid, errMsg] = validateAllOf(value, schema.allOf, path);
        return;
    end

    % Handle enum validation
    if isfield(schema, 'enum')
        [isValid, errMsg] = validateEnum(value, schema.enum);
        return;
    end

    % Handle const validation
    if isfield(schema, 'const')
        if ~isequal(value, schema.const)
            isValid = false;
            errMsg = sprintf('expected const value, got ''%s''', summarizeValue(value));
        end
        return;
    end

    % Get the type specification
    if ~isfield(schema, 'type')
        % No type specified - accept any value
        return;
    end

    schemaType = schema.type;

    % Handle union types (type can be a cell array of types)
    if iscell(schemaType)
        [isValid, errMsg] = validateUnionType(value, schemaType, schema, path);
        return;
    end

    % Validate based on type
    switch schemaType
        case 'string'
            [isValid, errMsg] = validateString(value);

        case 'number'
            [isValid, errMsg] = validateNumber(value);

        case 'integer'
            [isValid, errMsg] = validateInteger(value);

        case 'boolean'
            [isValid, errMsg] = validateBoolean(value);

        case 'null'
            [isValid, errMsg] = validateNull(value);

        case 'array'
            [isValid, errMsg] = validateArray(value, schema, path);

        case 'object'
            [isValid, errMsg] = validateObject(value, schema, path);

        otherwise
            % Treat unknown type as a MATLAB class name
            if ~isa(value, schemaType)
                isValid = false;
                errMsg = sprintf('expected type ''%s'', got ''%s''', schemaType, class(value));
            end
    end
end

function [isValid, errMsg] = validateString(value)
%VALIDATESTRING Validate that value is a string or char array
    isValid = ischar(value) || isstring(value);
    if ~isValid
        errMsg = sprintf('expected string, got ''%s''', class(value));
    else
        errMsg = '';
    end
end

function [isValid, errMsg] = validateNumber(value)
%VALIDATENUMBER Validate that value is numeric
    isValid = isnumeric(value) && isscalar(value);
    if ~isValid
        if ~isnumeric(value)
            errMsg = sprintf('expected number, got ''%s''', class(value));
        else
            errMsg = sprintf('expected scalar number, got %s', describeDimensions(value));
        end
    else
        errMsg = '';
    end
end

function [isValid, errMsg] = validateInteger(value)
%VALIDATEINTEGER Validate that value is an integer
    isValid = isnumeric(value) && isscalar(value) && ...
              (isinteger(value) || (isfloat(value) && value == floor(value)));
    if ~isValid
        if ~isnumeric(value)
            errMsg = sprintf('expected integer, got ''%s''', class(value));
        elseif ~isscalar(value)
            errMsg = sprintf('expected scalar integer, got %s', describeDimensions(value));
        else
            errMsg = sprintf('expected integer, got non-integer numeric value');
        end
    else
        errMsg = '';
    end
end

function [isValid, errMsg] = validateBoolean(value)
%VALIDATEBOOLEAN Validate that value is a logical
    isValid = islogical(value) && isscalar(value);
    if ~isValid
        if ~islogical(value)
            errMsg = sprintf('expected boolean, got ''%s''', class(value));
        else
            errMsg = sprintf('expected scalar boolean, got %s', describeDimensions(value));
        end
    else
        errMsg = '';
    end
end

function [isValid, errMsg] = validateNull(value)
%VALIDATENULL Validate that value is empty/null
    isValid = isempty(value) || isequal(value, missing) || ...
              (isnumeric(value) && isscalar(value) && isnan(value));
    if ~isValid
        errMsg = sprintf('expected null, got ''%s''', class(value));
    else
        errMsg = '';
    end
end

function [isValid, errMsg] = validateArray(value, schema, path)
%VALIDATEARRAY Validate that value is an array and validate its items
    isValid = true;
    errMsg = '';

    % Accept cell arrays or numeric/logical arrays
    if ~iscell(value) && ~isnumeric(value) && ~islogical(value) && ~isstring(value)
        isValid = false;
        errMsg = sprintf('expected array, got ''%s''', class(value));
        return;
    end

    % Validate array constraints
    if isfield(schema, 'minItems')
        if numel(value) < schema.minItems
            isValid = false;
            errMsg = sprintf('array has %d items, minimum is %d', numel(value), schema.minItems);
            return;
        end
    end

    if isfield(schema, 'maxItems')
        if numel(value) > schema.maxItems
            isValid = false;
            errMsg = sprintf('array has %d items, maximum is %d', numel(value), schema.maxItems);
            return;
        end
    end

    % Validate items if schema specifies item type
    if isfield(schema, 'items')
        itemSchema = schema.items;

        if iscell(itemSchema)
            % Tuple validation - each position has its own schema
            for i = 1:min(numel(value), numel(itemSchema))
                if iscell(value)
                    itemValue = value{i};
                else
                    itemValue = value(i);
                end
                itemPath = sprintf('%s[%d]', path, i);
                [isValid, errMsg] = validateValue(itemValue, itemSchema{i}, itemPath);
                if ~isValid
                    errMsg = sprintf('at index %d: %s', i, errMsg);
                    return;
                end
            end
        elseif isstruct(itemSchema)
            % All items share the same schema
            for i = 1:numel(value)
                if iscell(value)
                    itemValue = value{i};
                else
                    itemValue = value(i);
                end
                itemPath = sprintf('%s[%d]', path, i);
                [isValid, errMsg] = validateValue(itemValue, itemSchema, itemPath);
                if ~isValid
                    errMsg = sprintf('at index %d: %s', i, errMsg);
                    return;
                end
            end
        end
    end
end

function [isValid, errMsg] = validateObject(value, schema, path)
%VALIDATEOBJECT Validate that value is a struct and validate its properties
    isValid = true;
    errMsg = '';

    % Check if it's a struct
    if ~isstruct(value)
        isValid = false;
        errMsg = sprintf('expected object (struct), got ''%s''', class(value));
        return;
    end

    % Validate required properties -- convert required to string array
    if isfield(schema, 'required')
        required = schema.required;
        if ischar(required) || iscellstr(required) %#ok<ISCLSTR>
            required = string(required);
        end
        if isstring(required) == false
            error("prodserver:mcp:InvalidSchema", ...
                "Property 'required' must be a string array or " + ...
                "convertible to a string array. Instead it has " + ...
                "incompatible type '%s'.", class(required));
        end
        for i = 1:numel(required)
            propName = required(i);
            if ~isfield(value, propName)
                isValid = false;
                errMsg = sprintf('missing required property ''%s''', propName);
                return;
            end
        end
    end

    % Validate properties
    if isfield(schema, 'properties')
        propSchemas = schema.properties;
        propNames = fieldnames(propSchemas);

        for i = 1:numel(propNames)
            propName = propNames{i};
            if isfield(value, propName)
                propValue = value.(propName);
                propSchema = propSchemas.(propName);
                propPath = sprintf('%s.%s', path, propName);
                [isValid, errMsg] = validateValue(propValue, propSchema, propPath);
                if ~isValid
                    errMsg = sprintf('property ''%s'': %s', propName, errMsg);
                    return;
                end
            end
        end
    end

    % Validate additionalProperties if specified as false
    if isfield(schema, 'additionalProperties') && ...
       islogical(schema.additionalProperties) && ...
       ~schema.additionalProperties

        if isfield(schema, 'properties')
            allowedProps = fieldnames(schema.properties);
        else
            allowedProps = {};
        end
        actualProps = fieldnames(value);

        for i = 1:numel(actualProps)
            if ~ismember(actualProps{i}, allowedProps)
                isValid = false;
                errMsg = sprintf('unexpected property ''%s''', actualProps{i});
                return;
            end
        end
    end
end

function [isValid, errMsg] = validateUnionType(value, types, schema, path)
%VALIDATEUNIONTYPE Validate value against a union of types
    isValid = false;
    errMsg = '';
    errors = {};

    for i = 1:numel(types)
        typeName = types{i};
        subSchema = schema;
        subSchema.type = typeName;

        [valid, msg] = validateValue(value, subSchema, path);
        if valid
            isValid = true;
            return;
        end
        errors{end+1} = msg; %#ok<AGROW>
    end

    typeList = strjoin(string(types), ', ');
    errMsg = sprintf('expected one of [%s], got ''%s''', typeList, class(value));
end

function [isValid, errMsg] = validateAnyOf(value, schemas, path)
%VALIDATEANYOF Validate value matches at least one schema
    isValid = false;
    errMsg = '';

    for i = 1:numel(schemas)
        if iscell(schemas)
            subSchema = schemas{i};
        else
            subSchema = schemas(i);
        end
        [valid, ~] = validateValue(value, subSchema, path);
        if valid
            isValid = true;
            return;
        end
    end

    errMsg = sprintf('value does not match any of %d allowed schemas', numel(schemas));
end

function [isValid, errMsg] = validateOneOf(value, schemas, path)
%VALIDATEONEOF Validate value matches exactly one schema
    matchCount = 0;
    errMsg = '';

    for i = 1:numel(schemas)
        if iscell(schemas)
            subSchema = schemas{i};
        else
            subSchema = schemas(i);
        end
        [valid, ~] = validateValue(value, subSchema, path);
        if valid
            matchCount = matchCount + 1;
        end
    end

    isValid = (matchCount == 1);
    if matchCount == 0
        errMsg = sprintf('value does not match any of %d schemas (exactly one required)', numel(schemas));
    elseif matchCount > 1
        errMsg = sprintf('value matches %d schemas (exactly one required)', matchCount);
    end
end

function [isValid, errMsg] = validateAllOf(value, schemas, path)
%VALIDATEALLOF Validate value matches all schemas
    isValid = true;
    errMsg = '';

    for i = 1:numel(schemas)
        if iscell(schemas)
            subSchema = schemas{i};
        else
            subSchema = schemas(i);
        end
        [valid, msg] = validateValue(value, subSchema, path);
        if ~valid
            isValid = false;
            errMsg = sprintf('failed schema %d of %d: %s', i, numel(schemas), msg);
            return;
        end
    end
end

function [isValid, errMsg] = validateEnum(value, enumValues)
%VALIDATEENUM Validate value is one of the enumerated values
    isValid = false;
    errMsg = '';

    if iscell(enumValues)
        for i = 1:numel(enumValues)
            if isequal(value, enumValues{i})
                isValid = true;
                return;
            end
        end
    else
        if isequal(value, enumValues)
            isValid = true;
            return;
        end
    end

    errMsg = sprintf('value ''%s'' is not one of the allowed enum values', summarizeValue(value));
end

function className = extractClassName(refString)
%EXTRACTCLASSNAME Extract class name from a $ref string
    className = '';
    if ischar(refString) || isstring(refString)
        refString = char(refString);
        % Handle formats like "#/definitions/ClassName" or just "ClassName"
        parts = strsplit(refString, '/');
        className = parts{end};
    end
end

function desc = describeDimensions(value)
%DESCRIBEDIMENSIONS Create a string describing array dimensions
    sz = size(value);
    if isscalar(value)
        desc = 'scalar';
    elseif isvector(value)
        desc = sprintf('%d-element vector', numel(value));
    else
        dims = strjoin(string(sz), 'x');
        desc = sprintf('%s array', dims);
    end
end

function summary = summarizeValue(value)
%SUMMARIZEVALUE Create a concise string representation of a value
    if ischar(value)
        if numel(value) > 20
            summary = sprintf('char[1x%d]', numel(value));
        else
            summary = value;
        end
    elseif isstring(value) && isscalar(value)
        if strlength(value) > 20
            summary = sprintf('string[%d chars]', strlength(value));
        else
            summary = char(value);
        end
    elseif isnumeric(value) && isscalar(value)
        summary = num2str(value);
    elseif islogical(value) && isscalar(value)
        if value
            summary = 'true';
        else
            summary = 'false';
        end
    elseif isstruct(value)
        summary = sprintf('struct with %d fields', numel(fieldnames(value)));
    elseif iscell(value)
        summary = sprintf('cell array [%s]', strjoin(string(size(value)), 'x'));
    else
        summary = sprintf('%s [%s]', class(value), strjoin(string(size(value)), 'x'));
    end
end
