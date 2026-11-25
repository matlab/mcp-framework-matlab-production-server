function detail = validateArgumentsWithSchema(schema, names, values)
%VALIDATEARGUMENTSWITHSCHEMA Validate MATLAB arguments against a JSON-RPC schema
%   validateArgumentsWithSchema(SCHEMA, NAMES, VALUES) validates each value
%   in the cell array VALUES against the corresponding schema definition.
%   NAMES is a string array of argument names where NAMES(n) corresponds to
%   VALUES{n}. An error is issued identifying the first argument that fails
%   validation, including the argument name and a description of the type 
%   mismatch.
%
%   detail = validateArgumentsWithSchema(...) returns that description of
%   the mismatch instead of raising the error, or "" if every value is
%   valid. Other errors, such as a name with no schema, are still raised.
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

    detail = "";

    % Validate each argument
    for i = 1:numel(values)
        argName = names(i);
        argValue = values{i};

        if i <= numel(paramSchemas) && ~isempty(paramSchemas{i})
            paramSchema = paramSchemas{i};
            [isValid, errMsg] = validateValue(argValue, paramSchema, argName);

            if ~isValid && nargout > 0
                detail = string(errMsg);
                return
            elseif ~isValid
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

function [isValid, errMsg] = validateValue(value, schema, path, strict)
%VALIDATEVALUE Recursively validate a value against a schema. If STRICT,
%read the schema as JSON Schema does, in which a scalar is not an array (see
%validateArray); by default, as MATLAB does.
    if nargin < 4
        strict = false;
    end
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

    % Handle anyOf, oneOf, allOf combinators. The value must satisfy each,
    % and the schema's other keywords too. If it has none that are checked
    % -- as the wrapper's items, a number or the name of one, have none --
    % it is valid: each element of an array would otherwise pay for a
    % second pass that checks nothing.
    nullable = false;
    combinators = isfield(schema, {'anyOf', 'oneOf', 'allOf'});
    if any(combinators)
        if combinators(1)
            [isValid, errMsg] = validateAnyOf(value, schema.anyOf, path, strict);
            if ~isValid, return; end
        end
        if combinators(2)
            [isValid, errMsg] = validateOneOf(value, schema.oneOf, path, strict);
            if ~isValid, return; end
        end
        if combinators(3)
            [isValid, errMsg] = validateAllOf(value, schema.allOf, path, strict);
            if ~isValid, return; end
        end
        if ~any(isfield(schema, checkedKeywords()))
            return
        end
        nullable = admitsNull(schema);
        names = {'anyOf', 'oneOf', 'allOf'};
        schema = rmfield(schema, names(combinators));
    end

    % An enum or a const limits the value, and so do the schema's other
    % keywords: a member must also satisfy them.
    if isfield(schema, 'enum')
        [isValid, errMsg] = validateEnum(value, schema.enum);
        if ~isValid
            return;
        end
    end

    if isfield(schema, 'const')
        % The const comes from jsondecode, as the argument does, in the
        % same form.
        if ~jsonEqual(value, schema.const)
            isValid = false;
            % Double quotes: these are values, not the class names that
            % toolArgumentError's jsonTerms rewrites in single quotes.
            errMsg = sprintf('expected "%s", got "%s"', ...
                summarizeValue(schema.const), summarizeValue(value));
            return;
        end
    end

    % With no type, any value of any type is allowed, but a number must
    % still satisfy the keywords for numbers, a string those for strings,
    % an array those for arrays and an object those for objects. As in JSON
    % Schema, a single value is not an array here: the array keywords
    % beside a union of a scalar and an array constrain only the array.
    % Nor is null, which jsondecode gives as [], as it gives an empty array:
    % where an alternative beside them allows null, [] may be null, and the
    % array keywords don't constrain it.
    if ~isfield(schema, 'type')
        [isValid, errMsg] = validateConstraints(value, schema);
        arrayKeywords = {'items', 'minItems', 'maxItems', 'uniqueItems'};
        objectKeywords = {'properties', 'required', 'additionalProperties', ...
            'minProperties', 'maxProperties'};
        maybeNull = nullable && isnumeric(value) && isempty(value);
        if isValid && ~isJSONScalar(value) && ~maybeNull && ...
                any(isfield(schema, arrayKeywords))
            [isValid, errMsg] = validateArray(value, schema, path, strict);
        elseif isValid && isstruct(value) && isscalar(value) && ...
                any(isfield(schema, objectKeywords))
            [isValid, errMsg] = validateObject(value, schema, path, strict);
        end
        return;
    end

    schemaType = schema.type;

    % Handle union types (type can be a cell array of types)
    if iscell(schemaType)
        [isValid, errMsg] = validateUnionType(value, schemaType, schema, path, strict);
        return;
    end

    % Validate based on type
    switch schemaType
        case 'string'
            [isValid, errMsg] = validateString(value, schema);

        case 'number'
            [isValid, errMsg] = validateNumber(value);

        case 'integer'
            [isValid, errMsg] = validateInteger(value);

        case 'boolean'
            [isValid, errMsg] = validateBoolean(value);

        case 'null'
            [isValid, errMsg] = validateNull(value);

        case 'array'
            [isValid, errMsg] = validateArray(value, schema, path, strict);

        case 'object'
            [isValid, errMsg] = validateObject(value, schema, path, strict);

        otherwise
            % Treat unknown type as a MATLAB class name
            if ~isa(value, schemaType)
                isValid = false;
                errMsg = sprintf('expected type ''%s'', got ''%s''', schemaType, class(value));
            end
    end

    if isValid && ~strcmp(schemaType, 'array')
        [isValid, errMsg] = validateConstraints(value, schema);
    end
end

function [isValid, errMsg] = validateConstraints(value, schema)
%VALIDATECONSTRAINTS Validate a number against the schema's keywords for
%numbers, or a string against those for strings. JSON Schema applies them
%by what the value is, whatever the schema's type. (An array's are checked
%by validateArray; an object's by validateObject.)
    isValid = true;
    errMsg = '';
    % NaN is how jsondecode gives a null in a numeric array (JSON has no
    % NaN), and the keywords for numbers don't apply to null.
    if isnumeric(value) && isscalar(value) && isreal(value) && ~isnan(value)
        [isValid, errMsg] = validateNumberConstraints(double(value), schema);
    elseif (ischar(value) && (isrow(value) || isempty(value))) || ...
            (isstring(value) && isscalar(value) && ~ismissing(value))
        % A missing string, which only a MATLAB caller can pass, has no
        % characters to check, as NaN has no number.
        [isValid, errMsg] = validateStringConstraints(char(value), schema);
    end
end

function [isValid, errMsg] = validateNumberConstraints(v, schema)
%VALIDATENUMBERCONSTRAINTS minimum, maximum, exclusiveMinimum,
%exclusiveMaximum and multipleOf. exclusiveMinimum and exclusiveMaximum may
%be numbers, or, as in draft-04, booleans that make minimum and maximum
%exclusive.
    t = @(x) char(jsonText(x));
    checks = numberChecks(v, schema);
    for k = 1:size(checks, 1)
        [kind, ok, m] = checks{k,:};
        if ~ok
            isValid = false;
            switch kind
                case 'greater'
                    errMsg = sprintf('value %s must be greater than %s', t(v), t(m));
                case 'minimum'
                    errMsg = sprintf('value %s is less than the minimum, %s', t(v), t(m));
                case 'less'
                    errMsg = sprintf('value %s must be less than %s', t(v), t(m));
                case 'maximum'
                    errMsg = sprintf('value %s is greater than the maximum, %s', t(v), t(m));
                otherwise
                    errMsg = sprintf('value %s is not a multiple of %s', t(v), t(m));
            end
            return;
        end
    end
    isValid = true;
    errMsg = '';
end

function checks = numberChecks(v, schema)
%NUMBERCHECKS For each keyword for numbers in SCHEMA, in the order they are
%checked: the kind of limit it sets ('greater', 'minimum', 'less',
%'maximum' or 'multiple'), whether each element of V, an array of doubles
%with no NaN, satisfies it, and its bound. validateNumberConstraints checks
%one number by them, and allItemsValid an array.
    checks = cell(0, 3);

    lowerExclusive = isfield(schema, 'exclusiveMinimum') && ...
        isscalar(schema.exclusiveMinimum) && islogical(schema.exclusiveMinimum) && ...
        schema.exclusiveMinimum;
    if isNumberKeyword(schema, 'minimum')
        m = schema.minimum;
        if lowerExclusive
            checks(end+1, :) = {'greater', v > m, m};
        else
            checks(end+1, :) = {'minimum', v >= m, m};
        end
    end
    if isNumberKeyword(schema, 'exclusiveMinimum')
        m = schema.exclusiveMinimum;
        checks(end+1, :) = {'greater', v > m, m};
    end

    upperExclusive = isfield(schema, 'exclusiveMaximum') && ...
        isscalar(schema.exclusiveMaximum) && islogical(schema.exclusiveMaximum) && ...
        schema.exclusiveMaximum;
    if isNumberKeyword(schema, 'maximum')
        m = schema.maximum;
        if upperExclusive
            checks(end+1, :) = {'less', v < m, m};
        else
            checks(end+1, :) = {'maximum', v <= m, m};
        end
    end
    if isNumberKeyword(schema, 'exclusiveMaximum')
        m = schema.exclusiveMaximum;
        checks(end+1, :) = {'less', v < m, m};
    end

    if isNumberKeyword(schema, 'multipleOf') && schema.multipleOf > 0
        % 0.3/0.1 is 2.9999999999999996: allow a few units in the last
        % place of the quotient.
        m = schema.multipleOf;
        q = v / m;
        checks(end+1, :) = {'multiple', ...
            isfinite(q) & abs(q - round(q)) <= 4*eps(max(abs(q), 1)), m};
    end
end

function [isValid, errMsg] = validateStringConstraints(s, schema)
%VALIDATESTRINGCONSTRAINTS minLength, maxLength and pattern. JSON Schema
%counts a string's length in Unicode code points; MATLAB's char is UTF-16,
%in which a character outside the Basic Multilingual Plane, such as an
%emoji, is two, so its low surrogate isn't counted.
    isValid = false;
    n = nnz(s < 0xDC00 | s > 0xDFFF);
    if isNumberKeyword(schema, 'minLength') && ...
            n < schema.minLength
        errMsg = sprintf('string has %s, minimum is %d', counted(n, "character"), ...
            schema.minLength);
        return;
    end
    if isNumberKeyword(schema, 'maxLength') && ...
            n > schema.maxLength
        errMsg = sprintf('string has %s, maximum is %d', counted(n, "character"), ...
            schema.maxLength);
        return;
    end
    if isfield(schema, 'pattern') && ...
            (ischar(schema.pattern) || isstring(schema.pattern))
        p = char(schema.pattern);
        [usable, reason] = prodserver.mcp.validation.isJsonSchemaPattern(p);
        if usable
            % JSON Schema's patterns are ECMAScript's, which MATLAB's
            % regexp reads otherwise: \d, \b, . and others mean other
            % things. Match the pattern in MATLAB's form, and let it match
            % no characters: regexp otherwise finds no match in '', even
            % for ^$, nor a* in 'b'.
            m = prodserver.mcp.jsonrpc.ecmaPattern(p);
            matched = ~isempty(regexp(s, m, 'once', 'emptymatch'));
        else
            % build rejects such a pattern (see validateSchemaKeywords), so
            % this one came another way. regexp would match it otherwise
            % than JSON Schema means, or match nothing and reject every
            % call: skip the check.
            prodserver.mcp.logging.Log.instance().logOnce( ...
                "SchemaPattern|" + p, prodserver.mcp.logging.Level.Warning, ...
                "prodserver:mcp:InvalidJsonSchemaPattern", ...
                "Not checking the pattern ""%s"": %s", p, reason);
            matched = true;
        end
        if ~matched
            errMsg = sprintf('string %s does not match the pattern %s', ...
                jsonText(s), jsonText(p));
            return;
        end
    end
    isValid = true;
    errMsg = '';
end

function [isValid, errMsg] = validateString(value, schema)
%VALIDATESTRING Validate that value is a string or char array, and if the
%schema says "format": "date-time", ISO 8601 date-time text as
%parseISODateTime reads it. (Other formats are not checked.)
    isValid = ischar(value) || isstring(value);
    errMsg = '';
    if ~isValid
        errMsg = sprintf('expected string, got ''%s''', class(value));
    elseif nargin > 1 && prodserver.mcp.jsonrpc.isDateTimeSchema(schema)
        [~, isValid] = prodserver.mcp.jsonrpc.parseISODateTime(value);
        if ~isValid
            errMsg = sprintf("%s, got '%s'", ...
                prodserver.mcp.MCPConstants.DateTimeExpected, value);
        end
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

function [isValid, errMsg] = validateArray(value, schema, path, strict)
%VALIDATEARRAY Validate that value is an array and validate its items. If
%STRICT, a JSON scalar -- a number, boolean, string or object -- is not.
    isValid = true;
    errMsg = '';

    if strict && isJSONScalar(value)
        isValid = false;
        errMsg = sprintf('expected array, got ''%s''', class(value));
        return;
    end

    % A MATLAB scalar is a 1x1 array, so a single element satisfies an array
    % schema. A character row vector is one string, not an array of
    % characters; a struct array (which is how jsondecode delivers a JSON
    % array of objects with the same fields) is an array of its elements.
    if ischar(value) && (isrow(value) || isempty(value))
        value = {value};
    elseif isstruct(value)
        value = num2cell(value);
    end

    % Accept cell arrays or numeric/logical arrays
    if ~iscell(value) && ~isnumeric(value) && ~islogical(value) && ~isstring(value)
        isValid = false;
        errMsg = sprintf('expected array, got ''%s''', class(value));
        return;
    end

    % Validate array constraints
    if isNumberKeyword(schema, 'minItems')
        if numel(value) < schema.minItems
            isValid = false;
            errMsg = sprintf('array has %d items, minimum is %d', numel(value), schema.minItems);
            return;
        end
    end

    if isNumberKeyword(schema, 'maxItems')
        if numel(value) > schema.maxItems
            isValid = false;
            errMsg = sprintf('array has %d items, maximum is %d', numel(value), schema.maxItems);
            return;
        end
    end

    if isfield(schema, 'uniqueItems') && isscalar(schema.uniqueItems) && ...
            islogical(schema.uniqueItems) && schema.uniqueItems
        [i, j] = firstEqualItems(value);
        if i > 0
            isValid = false;
            errMsg = sprintf('items %d and %d are equal, but must be unique', i, j);
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
                [isValid, errMsg] = validateValue(itemValue, itemSchema{i}, itemPath, strict);
                if ~isValid
                    errMsg = sprintf('at index %d: %s', i, errMsg);
                    return;
                end
            end
        elseif isstruct(itemSchema)
            % All items share the same schema. An array of numbers,
            % booleans or strings is checked all at once if it can be;
            % otherwise, or if it fails, item by item, which says which.
            if allItemsValid(value, itemSchema)
                return
            end
            for i = 1:numel(value)
                if iscell(value)
                    itemValue = value{i};
                else
                    itemValue = value(i);
                end
                itemPath = sprintf('%s[%d]', path, i);
                [isValid, errMsg] = validateValue(itemValue, itemSchema, itemPath, strict);
                if ~isValid
                    % A single value has no position worth naming.
                    if numel(value) > 1
                        errMsg = sprintf('at index %d: %s', i, errMsg);
                    end
                    return;
                end
            end
        end
    end
end

function tf = isNumberKeyword(schema, name)
%ISNUMBERKEYWORD True if SCHEMA has the keyword NAME, and its value is one
%real number, as minimum and minLength must be. build rejects a schema in
%which it isn't (see validateSchemaKeywords); one that came another way is
%not checked against it, rather than raising an error at every call.
    tf = isfield(schema, name) && isnumeric(schema.(name)) && ...
        isscalar(schema.(name)) && isreal(schema.(name)) && ...
        ~isnan(schema.(name));
end

function tf = allItemsValid(v, s)
%ALLITEMSVALID True if each item of V, as validateArray gives it, would
%satisfy the schema S, as checking them all at once shows. V is a real
%numeric array, a logical array, a string array with no missing strings,
%or a cell of numbers, booleans and strings, such as a JSON array of
%numbers and "Inf" decodes to. False if V or S is of another kind, or if
%an item fails: validateArray then checks each item, as validateValue
%does, so a false only costs time. A true must mean what that would find.
    tf = false;
    n = numel(v);
    if isnumeric(v) && isreal(v)
        groups = {"number", double(v(:)), (1:n)'};
    elseif islogical(v)
        groups = {"boolean", v(:), (1:n)'};
    elseif isstring(v) && ~any(ismissing(v), 'all')
        groups = {"string", v(:), (1:n)'};
    elseif iscell(v)
        % Items by kind: a real double, a boolean, a char row. Any other
        % item, such as [] (null) or a struct, is left to validateValue.
        v = v(:);
        one = cellfun('prodofsize', v) == 1;
        isNumber = one & cellfun('isclass', v, 'double') & cellfun('isreal', v);
        isBoolean = one & cellfun('islogical', v);
        isText = cellfun('isclass', v, 'char') & cellfun('ndims', v) == 2 & ...
            (cellfun('size', v, 1) == 1 | ...
            (cellfun('size', v, 1) == 0 & cellfun('size', v, 2) == 0));
        if ~all(isNumber | isBoolean | isText)
            return
        end
        groups = cell(0, 3);
        if any(isNumber)
            groups(end+1, :) = {"number", [v{isNumber}]', find(isNumber)};
        end
        if any(isBoolean)
            groups(end+1, :) = {"boolean", [v{isBoolean}]', find(isBoolean)};
        end
        if any(isText)
            groups(end+1, :) = {"string", string(v(isText)), find(isText)};
        end
    else
        return
    end
    for g = 1:size(groups, 1)
        if ~all(itemsValid(groups{g,2}, groups{g,1}, s))
            return
        end
    end
    tf = true;
end

function ok = itemsValid(x, kind, s)
%ITEMSVALID For each item of the column X, all of one KIND -- "number"
%(doubles), "boolean" or "string" (a string array) -- true if it satisfies
%the schema S, as validateValue would find; false if it doesn't, or if
%that can't be shown for all of them at once.
    ok = false(size(x));
    if ~isstruct(s) || ~isscalar(s) || ...
            any(isfield(s, {'x]ref', 'ref', 'matlabClass', 'oneOf', 'const'}))
        return
    end
    numberKeys = {'minimum', 'maximum', 'exclusiveMinimum', ...
        'exclusiveMaximum', 'multipleOf'};
    stringKeys = {'minLength', 'maxLength', 'pattern'};
    others = setdiff(checkedKeywords(), [{'type', 'enum'} numberKeys stringKeys]);
    if any(isfield(s, others))
        return
    end
    ok(:) = true;

    % An item satisfies an anyOf if it satisfies one of its alternatives,
    % which may differ from item to item, and an allOf if all of them.
    if isfield(s, 'anyOf')
        alts = s.anyOf;
        some = false(size(x));
        for k = 1:numel(alts)
            if iscell(alts), a = alts{k}; else, a = alts(k); end
            some = some | itemsValid(x, kind, a);
            if all(some), break, end
        end
        ok = ok & some;
    end
    if isfield(s, 'allOf')
        alts = s.allOf;
        for k = 1:numel(alts)
            if iscell(alts), a = alts{k}; else, a = alts(k); end
            ok = ok & itemsValid(x, kind, a);
        end
    end

    if isfield(s, 'enum')
        ok = ok & enumMembers(x, kind, s.enum);
    end

    if isfield(s, 'type')
        types = string(s.type);
        switch kind
            case "number"
                % NaN is a number to validateNumber, and null; an integer
                % has no fraction, and Inf has none.
                if ~all(ismember(types, ["number" "integer" "null"]))
                    ok(:) = false;
                elseif ~any(types == "number")
                    whole = false(size(x));
                    if any(types == "integer")
                        whole = x == floor(x);
                    end
                    if any(types == "null")
                        whole = whole | isnan(x);
                    end
                    ok = ok & whole;
                end
            case "boolean"
                if ~isequal(types, "boolean")
                    ok(:) = false;
                end
            case "string"
                if ~isequal(types, "string") || ...
                        prodserver.mcp.jsonrpc.isDateTimeSchema(s)
                    ok(:) = false;
                end
        end
    end

    % The keywords for numbers apply to numbers that aren't NaN (null), and
    % those for strings to strings, whatever the type.
    switch kind
        case "number"
            number = ~isnan(x);
            checks = numberChecks(x(number), s);
            met = true(nnz(number), 1);
            for k = 1:size(checks, 1)
                met = met & checks{k,2};
            end
            ok(number) = ok(number) & met;
        case "string"
            ok = ok & stringsValid(x, s);
    end
end

function ok = enumMembers(x, kind, enumValues)
%ENUMMEMBERS For each item of X, as itemsValid has it, true if it equals a
%member of the enum, as validateEnum compares them (jsonEqual): a string a
%string, a number a number and a boolean a boolean. False for every item if
%a member is of another kind, such as null or an array: validateEnum
%compares those.
    ok = false(size(x));
    members = prodserver.mcp.jsonrpc.unstackDecodedArray(enumValues);
    text = cellfun(@(m) (ischar(m) && isrow(m)) || ...
        (isstring(m) && isscalar(m) && ~ismissing(m)), members);
    bool = cellfun(@(m) islogical(m) && isscalar(m), members);
    number = cellfun(@(m) isnumeric(m) && isscalar(m) && isreal(m) && ...
        isfinite(m), members);
    if ~all(text | bool | number)
        return
    end
    switch kind
        case "string"
            ok = ismember(x, string(members(text)));
        case "boolean"
            ok = ismember(x, [false(0, 1); members{bool}]);
        case "number"
            ok = ismember(x, cellfun(@double, members(number)));
    end
end

function ok = stringsValid(v, schema)
%STRINGSVALID For each string of the string array V, true if it satisfies
%SCHEMA's minLength, maxLength and pattern, as validateStringConstraints
%checks one. False for all of them if the pattern isn't one the server
%checks: that's for validateStringConstraints to say.
    v = v(:);
    ok = true(size(v));
    n = strlength(v);
    % A character outside the Basic Multilingual Plane is two UTF-16 code
    % units, and is counted once.
    pairs = contains(v, characterListPattern(char(0xDC00), char(0xDFFF)));
    if any(pairs)
        n(pairs) = cellfun(@(c) nnz(c < 0xDC00 | c > 0xDFFF), cellstr(v(pairs)));
    end
    if isNumberKeyword(schema, 'minLength')
        ok = ok & n >= schema.minLength;
    end
    if isNumberKeyword(schema, 'maxLength')
        ok = ok & n <= schema.maxLength;
    end
    if isfield(schema, 'pattern') && ...
            (ischar(schema.pattern) || isstring(schema.pattern))
        p = char(schema.pattern);
        if ~prodserver.mcp.validation.isJsonSchemaPattern(p)
            ok(:) = false;
            return
        end
        m = prodserver.mcp.jsonrpc.ecmaPattern(p);
        at = regexp(cellstr(v), m, 'once', 'emptymatch');
        ok = ok & ~cellfun('isempty', at);
    end
end

function k = checkedKeywords()
%CHECKEDKEYWORDS The keywords validateValue checks, other than anyOf, oneOf
%and allOf, and those it checks first ($ref and matlabClass). A schema
%with none of them, such as one with only a description, admits any value.
%format is checked only with type, which is one of them.
    k = {'type', 'enum', 'const', ...
        'minimum', 'maximum', 'exclusiveMinimum', 'exclusiveMaximum', 'multipleOf', ...
        'minLength', 'maxLength', 'pattern', ...
        'items', 'minItems', 'maxItems', 'uniqueItems', ...
        'properties', 'required', 'additionalProperties', ...
        'minProperties', 'maxProperties'};
end

function tf = admitsNull(schema)
%ADMITSNULL True if one of SCHEMA's alternatives (anyOf or oneOf) has the
%type null, or a type list with null in it.
    tf = false;
    for c = {'anyOf', 'oneOf'}
        if ~isfield(schema, c{1})
            continue
        end
        alts = schema.(c{1});
        for i = 1:numel(alts)
            if iscell(alts)
                a = alts{i};
            else
                a = alts(i);
            end
            if isstruct(a) && isscalar(a) && isfield(a, 'type') && ...
                    any(strcmp(string(a.type), "null"))
                tf = true;
                return
            end
        end
    end
end

function tf = isJSONScalar(value)
%ISJSONSCALAR True for a value jsondecode gives for a JSON number, boolean,
%string or object -- or for a JSON array of one of them, which it decodes
%the same way.
    tf = ((isnumeric(value) || islogical(value)) && isscalar(value)) || ...
        (ischar(value) && (isrow(value) || isempty(value))) || ...
        (isstring(value) && isscalar(value)) || ...
        (isstruct(value) && isscalar(value));
end

function [i, j] = firstEqualItems(value)
%FIRSTEQUALITEMS The positions of an item of an array, as validateArray
%gives it -- a cell, or a numeric, logical or string array -- and of the
%first later item equal to it (see jsonEqual), for the first item that has
%one. 0 and 0 if every item is unique. A matrix's items are its rows (see
%unstackDecodedArray), as a JSON array of arrays decodes.
%
%   A vector of numbers, booleans or strings, or a cell of strings, is
%   checked with unique; other items, pair by pair.
    i = 0;
    j = 0;
    if (isnumeric(value) || islogical(value) || isstring(value)) && ...
            (isvector(value) || isempty(value))
        [i, j] = firstRepeat(value(:));
        return
    elseif iscellstr(value) && all(cellfun(@(c) isrow(c) || isempty(c), value(:))) %#ok<ISCLSTR>
        [i, j] = firstRepeat(string(value(:)));
        return
    elseif iscell(value)
        items = value(:);
    else
        items = prodserver.mcp.jsonrpc.unstackDecodedArray(value);
    end
    for a = 1:numel(items) - 1
        for b = a + 1:numel(items)
            if jsonEqual(items{a}, items{b})
                i = a;
                j = b;
                return;
            end
        end
    end
end

function [i, j] = firstRepeat(v)
%FIRSTREPEAT For a column V of numbers, booleans or strings: the position
%of the first item equal to a later one, and of the first such later one.
%0 and 0 if none is. NaN, as jsondecode gives null among numbers, equals
%NaN, as null equals null.
    i = 0;
    j = 0;
    nulls = false(size(v));
    if isfloat(v)
        nulls = isnan(v);
    end
    [~, first, which] = unique(v(~nulls), 'stable');
    at = find(~nulls);
    % Each item's first occurrence, by position in V.
    firstAt = zeros(size(v));
    firstAt(at) = at(first(which));
    if nnz(nulls) > 1
        n = find(nulls);
        firstAt(n) = n(1);
    end
    repeated = find(firstAt ~= (1:numel(v))' & firstAt > 0);
    if isempty(repeated)
        return
    end
    % The item with a repeat that comes first, and its first repeat.
    i = min(firstAt(repeated));
    later = repeated(firstAt(repeated) == i);
    j = later(1);
end

function tf = jsonEqual(a, b)
%JSONEQUAL True if A and B, as jsondecode gives values, are the same JSON
%value, as enum, const and uniqueItems compare them: numbers by value,
%whatever their class; text whether char or string; and null (NaN, or [])
%equal to null. A boolean is not a number, nor text a number.
%
%   A value of a class jsondecode never gives, such as a categorical, which
%   only a MATLAB caller (mustMatchSchema) can pass, is compared with
%   isequal, as it was: categorical("a") is the member "a".
    if ~isDecodedClass(a) || ~isDecodedClass(b)
        tf = isequal(a, b);
    elseif isNull(a) || isNull(b)
        tf = isNull(a) && isNull(b);
    elseif isText(a) || isText(b)
        tf = isText(a) && isText(b) && string(a) == string(b);
    elseif islogical(a) || islogical(b)
        tf = islogical(a) && islogical(b) && isequal(a, b);
    elseif isnumeric(a) || isnumeric(b)
        tf = isnumeric(a) && isnumeric(b) && isreal(a) && isreal(b) && ...
            isequal(size(a), size(b)) && isequaln(double(a), double(b));
    elseif isstruct(a) || isstruct(b)
        tf = isstruct(a) && isstruct(b) && numel(a) == numel(b) && ...
            isempty(setxor(fieldnames(a), fieldnames(b)));
        names = fieldnames(a);
        for k = 1:numel(a)
            for f = 1:numel(names)
                if ~tf, return; end
                tf = jsonEqual(a(k).(names{f}), b(k).(names{f}));
            end
        end
    elseif iscell(a) || iscell(b)
        tf = iscell(a) && iscell(b) && numel(a) == numel(b);
        for k = 1:numel(a)
            if ~tf, return; end
            tf = jsonEqual(a{k}, b{k});
        end
    else
        tf = isequaln(a, b);
    end
end

function tf = isDecodedClass(x)
%ISDECODEDCLASS True for a value of a class jsondecode gives, or a string.
    tf = isnumeric(x) || islogical(x) || ischar(x) || isstring(x) || ...
        isstruct(x) || iscell(x);
end

function tf = isNull(x)
%ISNULL True for a value jsondecode gives for null: [], or NaN among numbers.
    tf = isfloat(x) && (isempty(x) || (isscalar(x) && isnan(x)));
end

function tf = isText(x)
%ISTEXT True for one string: a char row (or ''), or a string scalar.
    tf = (ischar(x) && (isrow(x) || isempty(x))) || (isstring(x) && isscalar(x));
end

function [isValid, errMsg] = validateObject(value, schema, path, strict)
%VALIDATEOBJECT Validate that value is a struct and validate its properties
    isValid = true;
    errMsg = '';

    % Check if it's a struct. A JSON array of objects decodes to a struct
    % array, which is not one object.
    if ~isstruct(value)
        isValid = false;
        errMsg = sprintf('expected object (struct), got ''%s''', class(value));
        return;
    end
    if ~isscalar(value)
        isValid = false;
        errMsg = sprintf('expected object (struct), got an array of %d', ...
            numel(value));
        return;
    end

    n = numel(fieldnames(value));
    if isNumberKeyword(schema, 'minProperties') && ...
            n < schema.minProperties
        isValid = false;
        errMsg = sprintf('object has %s, minimum is %d', counted(n, "property", "properties"), ...
            schema.minProperties);
        return;
    end
    if isNumberKeyword(schema, 'maxProperties') && ...
            n > schema.maxProperties
        isValid = false;
        errMsg = sprintf('object has %s, maximum is %d', counted(n, "property", "properties"), ...
            schema.maxProperties);
        return;
    end

    % Validate required properties. requiredNames treats "required":[]
    % (a 0x0 double after jsondecode) as the empty list, not a type error
    % (ND8), and raises InvalidSchema for anything else that is not text.
    required = prodserver.mcp.internal.requiredNames(schema);
    for i = 1:numel(required)
        propName = required(i);
        if ~isfield(value, propName)
            isValid = false;
            errMsg = sprintf('missing required property ''%s''', propName);
            return;
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
                [isValid, errMsg] = validateValue(propValue, propSchema, propPath, strict);
                if ~isValid
                    errMsg = sprintf('property ''%s'': %s', propName, errMsg);
                    return;
                end
            end
        end
    end

    % Validate additionalProperties if specified as false
    if isfield(schema, 'additionalProperties') && ...
       isscalar(schema.additionalProperties) && ...
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

function [isValid, errMsg] = validateUnionType(value, types, schema, path, strict)
%VALIDATEUNIONTYPE Validate value against a union of types. A value that
%may be one JSON value -- a number, boolean, string or object, or [], as
%null decodes -- is read as one first, as JSON Schema reads it, and as an
%array only if no other type in the list describes it: then the keywords
%for strings limit a string under ["array","string"], and the keywords for
%arrays don't limit a number under ["array","number"], whatever the order.
    isValid = false;
    errMsg = '';
    errors = {};
    listed = types;

    if isJSONScalar(value) || (isnumeric(value) && isempty(value))
        types = types(:);
        isArray = strcmp(string(types), "array");
        types = [types(~isArray); types(isArray)];
    end

    for i = 1:numel(types)
        typeName = types{i};
        subSchema = schema;
        subSchema.type = typeName;

        [valid, msg] = validateValue(value, subSchema, path, strict);
        if valid
            isValid = true;
            return;
        end
        % A value of this type that fails the schema for another reason
        % -- a string that isn't a date-time -- says why.
        if validateValue(value, struct('type', typeName), path, strict)
            errMsg = msg;
            return;
        end
        errors{end+1} = msg; %#ok<AGROW>
    end

    typeList = strjoin(string(listed), ', ');
    errMsg = sprintf('expected one of [%s], got ''%s''', typeList, class(value));
end

function [isValid, errMsg] = validateAnyOf(value, schemas, path, strict)
%VALIDATEANYOF Validate value matches at least one schema
    isValid = false;
    errMsg = '';

    for i = 1:numel(schemas)
        if iscell(schemas)
            subSchema = schemas{i};
        else
            subSchema = schemas(i);
        end
        [valid, ~] = validateValue(value, subSchema, path, strict);
        if valid
            isValid = true;
            return;
        end
    end

    errMsg = sprintf('value does not match any of %d allowed schemas', numel(schemas));
end

function [isValid, errMsg] = validateOneOf(value, schemas, path, strict)
%VALIDATEONEOF Validate value matches exactly one schema. A scalar satisfies
%an array schema, so it would match both {"type":"number"} and an array of
%numbers, which JSON Schema keeps apart. So count the matches as JSON Schema
%does first; only if there are none, count them again reading a scalar as
%an array of one, as a JSON array of one element decodes.
    errMsg = '';

    matchCount = countMatches(value, schemas, path, true);
    if matchCount == 0 && ~strict
        matchCount = countMatches(value, schemas, path, false);
    end

    isValid = (matchCount == 1);
    if matchCount == 0
        errMsg = sprintf('value does not match any of %d schemas (exactly one required)', numel(schemas));
    elseif matchCount > 1
        errMsg = sprintf('value matches %d schemas (exactly one required)', matchCount);
    end
end

function n = countMatches(value, schemas, path, strict)
%COUNTMATCHES The number of SCHEMAS (a cell or struct array) VALUE matches.
    n = 0;
    for i = 1:numel(schemas)
        if iscell(schemas)
            subSchema = schemas{i};
        else
            subSchema = schemas(i);
        end
        if validateValue(value, subSchema, path, strict)
            n = n + 1;
        end
    end
end

function [isValid, errMsg] = validateAllOf(value, schemas, path, strict)
%VALIDATEALLOF Validate value matches all schemas
    isValid = true;
    errMsg = '';

    for i = 1:numel(schemas)
        if iscell(schemas)
            subSchema = schemas{i};
        else
            subSchema = schemas(i);
        end
        [valid, msg] = validateValue(value, subSchema, path, strict);
        if ~valid
            isValid = false;
            errMsg = sprintf('failed schema %d of %d: %s', i, numel(schemas), msg);
            return;
        end
    end
end

function [isValid, errMsg] = validateEnum(value, enumValues)
%VALIDATEENUM Validate value is one of the enumerated values. ENUMVALUES is
%the enum's JSON array as jsondecode stacks it, or a cell of its members.
    isValid = true;
    errMsg = '';

    members = prodserver.mcp.jsonrpc.unstackDecodedArray(enumValues);
    for i = 1:numel(members)
        if jsonEqual(value, asReceived(members{i}))
            return;
        end
    end

    isValid = false;
    allowed = strjoin(cellfun(@jsonText, members'), ", ");
    errMsg = sprintf('value %s is not one of %s', jsonText(value), allowed);
end

function t = jsonText(value)
%JSONTEXT A value as JSON, as the client wrote it: "fast", 2, [1,2]. A long
%value, or one with no JSON form, is summarized, in double quotes.
    try
        t = string(jsonencode(value));
    catch
        t = "";
    end
    if strlength(t) == 0 || strlength(t) > 40
        t = string('"') + summarizeValue(value) + '"';
    end
end

function v = asReceived(member)
%ASRECEIVED A member of an enum in the form an argument arrives in: as
%jsondecode gives the member's JSON. A row of a matrix arrives as a column,
%a cell of numbers as a numeric array, and NaN, which a schema's null
%decodes to among numbers, as []. A member with no JSON form is as it is.
%
%   A string, or a finite number or boolean, arrives as it is (jsonEqual
%   compares char with string, and numbers of any class), so it needs no
%   encoding: every enum the framework generates is one of strings.
    if (ischar(member) && isrow(member)) || ...
            (isstring(member) && isscalar(member) && ~ismissing(member)) || ...
            ((isnumeric(member) || islogical(member)) && isscalar(member) && ...
            isreal(member) && isfinite(member))
        v = member;
        return
    end
    try
        v = jsondecode(jsonencode(member));
    catch
        v = member;
    end
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

function text = counted(n, one, many)
%COUNTED N and the noun for N things: "1 character", "3 characters".
    if nargin < 3
        many = one + "s";
    end
    if n == 1
        text = "1 " + one;
    else
        text = n + " " + many;
    end
end
