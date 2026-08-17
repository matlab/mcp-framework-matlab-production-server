function desc = generateDescription(param)
%generateDescription Auto-generate a parameter description from metadata.
%   Creates a concise, LLM-friendly description from metafunction signature
%   data when no hand-written comment is available.
%
%   param - A single element from metafunction().Signature.Inputs or .Outputs

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.hasField

    parts = string.empty;

    % Expand the parameter name into natural language
    name = string(param.Identifier.Name);
    expanded = expandName(name);
    if strlength(expanded) > 0 && expanded ~= name
        parts(end+1) = expanded;
    end

    % Determine type
    typeName = "";
    if hasField(param, "Validation.Class") && ~isempty(param.Validation.Class)
        typeName = string(param.Validation.Class.Name);
    end

    % Determine size description
    sizeDesc = "";
    if hasField(param, "Validation.Size") && ~isempty(param.Validation.Size)
        sizeDesc = sizeToNaturalLanguage(param.Validation.Size);
    end

    % Build type phrase
    if strlength(sizeDesc) > 0 && strlength(typeName) > 0
        parts(end+1) = sizeDesc + " " + typeName;
    elseif strlength(typeName) > 0
        parts(end+1) = upper(extractBefore(typeName,2)) + extractAfter(typeName,1);
    end

    % Required/optional status
    if param.Required
        parts(end+1) = "(required)";
    else
        parts(end+1) = "(optional)";
    end

    if isempty(parts)
        desc = name;
    else
        % If no semantic expansion was added, prefix with name
        if isempty(expanded) || expanded == name || strlength(expanded) == 0
            parts = [name, parts];
        end
        desc = strjoin(parts, ". ") + ".";
    end
end

function expanded = expandName(name)
%expandName Convert camelCase or snake_case parameter names to words.

    % Don't expand single-character names
    if strlength(name) <= 1
        expanded = "";
        return;
    end

    % Split camelCase: insert space before each uppercase letter
    chars = char(name);
    result = "";
    for i = 1:numel(chars)
        if i > 1 && chars(i) >= 'A' && chars(i) <= 'Z'
            result = result + " " + lower(chars(i));
        elseif chars(i) == '_'
            result = result + " ";
        else
            result = result + chars(i);
        end
    end
    result = strtrim(result);

    % Apply common MATLAB abbreviation expansions
    persistent abbreviations
    if isempty(abbreviations)
        abbreviations = dictionary(...
            ["num", "max", "min", "iter", "tol", "idx", "len", "pts", ...
             "coeff", "freq", "vel", "pos", "val", "fcn", "func"], ...
            ["number of", "maximum", "minimum", "iterations", "tolerance", ...
             "index", "length", "points", "coefficient", "frequency", ...
             "velocity", "position", "value", "function", "function"]);
    end

    words = split(result, " ");
    for i = 1:numel(words)
        if isKey(abbreviations, words(i))
            words(i) = abbreviations(words(i));
        end
    end
    expanded = strjoin(words, " ");

    % Capitalize first letter
    if strlength(expanded) > 0
        expanded = upper(extractBefore(expanded, 2)) + extractAfter(expanded, 1);
    end
end

function desc = sizeToNaturalLanguage(dims)
%sizeToNaturalLanguage Convert MATLAB dimension metadata to readable text.

    if numel(dims) ~= 2
        desc = "";
        return;
    end

    d1 = dimValue(dims(1));
    d2 = dimValue(dims(2));

    if d1 == 1 && d2 == 1
        desc = "Scalar";
    elseif d1 == 1 && isinf(d2)
        desc = "Row vector of";
    elseif isinf(d1) && d2 == 1
        desc = "Column vector of";
    elseif d1 == 1 && d2 > 1
        desc = d2 + "-element row vector of";
    elseif isinf(d1) && d2 > 1
        desc = "Matrix with " + d2 + " columns of";
    elseif isinf(d1) && isinf(d2)
        desc = "Matrix of";
    elseif d1 > 1 && d2 > 1
        desc = d1 + "x" + d2 + " matrix of";
    else
        desc = "";
    end
end

function v = dimValue(dim)
%dimValue Extract numeric value from a dimension metadata object.
    if isa(dim, 'matlab.metadata.UnrestrictedDimension')
        v = Inf;
    elseif isa(dim, 'matlab.metadata.FixedDimension')
        v = dim.Length;
    else
        v = Inf;
    end
end
