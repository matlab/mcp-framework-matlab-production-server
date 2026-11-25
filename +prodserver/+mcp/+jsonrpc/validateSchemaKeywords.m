function validateSchemaKeywords(schema)
%validateSchemaKeywords Error if a schema has a keyword the server can't check.
%   validateSchemaKeywords(schema) raises an error for the first keyword in
%   SCHEMA, a JSON Schema as jsondecode gives it, at any depth, whose value
%   the server can't check arguments against:
%
%     - a pattern that isJsonSchemaPattern rejects, with the error of
%       mustBeJsonSchemaPattern. MATLAB's regexp would match it otherwise
%       than JSON Schema means, or match nothing, and reject every call.
%     - a length or count -- minLength, maxLength, minItems, maxItems,
%       minProperties, maxProperties, minContains, maxContains -- that is
%       not a non-negative integer; a bound -- minimum, maximum,
%       exclusiveMinimum, exclusiveMaximum -- that is not a number (or, for
%       the exclusive ones, a boolean, as in draft-04); a multipleOf that
%       is not a number greater than 0; or a uniqueItems that is not a
%       boolean. The error is prodserver:mcp:InvalidSchemaKeyword.
%
%   The values of enum, examples, default and const are data, not schemas,
%   and are not searched; nor are the names of properties: a property named
%   pattern is not the keyword.

% Copyright 2026 The MathWorks, Inc.

    if isstruct(schema)
        for k = 1:numel(schema)
            validateOne(schema(k));
        end
    elseif iscell(schema)
        for k = 1:numel(schema)
            prodserver.mcp.jsonrpc.validateSchemaKeywords(schema{k});
        end
    end
end

function validateOne(s)
% S is one schema: an object whose fields are keywords.

    % Keywords whose value maps names to schemas, as jsondecode names them.
    named = ["properties" "patternProperties" "dependentSchemas" ...
        "definitions" "x_defs"];
    counts = ["minLength" "maxLength" "minItems" "maxItems" ...
        "minProperties" "maxProperties" "minContains" "maxContains"];
    bounds = ["minimum" "maximum"];
    exclusive = ["exclusiveMinimum" "exclusiveMaximum"];

    for f = string(fieldnames(s))'
        v = s.(f);
        if f == "pattern" && ~isstruct(v)
            prodserver.mcp.validation.mustBeJsonSchemaPattern(v);
        elseif ismember(f, counts)
            if ~(isNumber(v) && v >= 0 && v == round(v))
                invalid(f, v, "a non-negative integer");
            end
        elseif ismember(f, bounds)
            if ~isNumber(v)
                invalid(f, v, "a number");
            end
        elseif ismember(f, exclusive)
            if ~isNumber(v) && ~(islogical(v) && isscalar(v))
                invalid(f, v, "a number");
            end
        elseif f == "multipleOf"
            if ~(isNumber(v) && v > 0)
                invalid(f, v, "a number greater than 0");
            end
        elseif f == "uniqueItems"
            if ~(islogical(v) && isscalar(v))
                invalid(f, v, "true or false");
            end
        elseif ismember(f, ["enum" "examples" "default" "const" ...
                "dependentRequired"]) || (startsWith(f, "x_") && f ~= "x_defs")
            % Data, property names, and extensions such as "x-meta"
            % (jsondecode's x_meta), whose fields aren't keywords. ($defs
            % is x_defs, and holds schemas.)
            continue
        elseif f == "dependencies"
            % Each property's schema, or, as in dependentRequired, a list
            % of property names, which are data.
            if isstruct(v) && isscalar(v)
                for name = string(fieldnames(v))'
                    if isstruct(v.(name))
                        prodserver.mcp.jsonrpc.validateSchemaKeywords(v.(name));
                    end
                end
            end
        elseif ismember(f, named) && isstruct(v) && isscalar(v)
            for name = string(fieldnames(v))'
                prodserver.mcp.jsonrpc.validateSchemaKeywords(v.(name));
            end
        else
            prodserver.mcp.jsonrpc.validateSchemaKeywords(v);
        end
    end
end

function tf = isNumber(v)
% One real number: not null, which jsondecode gives as [], nor a list.
    tf = isnumeric(v) && isscalar(v) && isreal(v) && isfinite(v);
end

function invalid(keyword, v, expected)
    try
        given = string(jsonencode(v));
        if isnumeric(v) && isempty(v)
            given = "null";
        end
    catch
        given = "a " + class(v);
    end
    error("prodserver:mcp:InvalidSchemaKeyword", ...
        "The value of %s must be %s, not %s.", keyword, expected, given);
end
