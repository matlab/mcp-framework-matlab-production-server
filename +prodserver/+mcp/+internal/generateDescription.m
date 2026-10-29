function desc = generateDescription(param, io)
%generateDescription Auto-generate a parameter description from metadata.
%   Creates a concise, LLM-friendly description from metafunction signature
%   data when no hand-written comment is available.
%
%   param - A single element from metafunction().Signature.Inputs or .Outputs
%   io    - "input" or "output"
%
%   The description names the parameter's role and, where the arguments
%   block declares them, its size and type: "Input window size.", "Output
%   y.", "Input x: scalar double." It doesn't say whether the parameter is
%   required: the schema's required list does, and a second statement in
%   prose can only disagree with it.

% Copyright 2026 The MathWorks, Inc.

    arguments
        param
        io (1,1) string {mustBeMember(io, ["input", "output"])}
    end

    import prodserver.mcp.internal.hasField

    % Role, then the name in words. The name itself is never recased, so
    % parameters x and X stay distinct.
    name = string(param.Identifier.Name);
    role = "Input";
    if io == "output"
        role = "Output";
    end
    desc = role + " " + expandName(name);

    % Type and size, if the arguments block declares them.
    typeName = "";
    if hasField(param, "Validation.Class") && ~isempty(param.Validation.Class)
        typeName = string(param.Validation.Class.Name);
    end
    sizeDesc = "";
    if hasField(param, "Validation.Size") && ~isempty(param.Validation.Size)
        sizeDesc = sizeToNaturalLanguage(param.Validation.Size);
    end
    if strlength(sizeDesc) > 0 && strlength(typeName) > 0
        desc = desc + ": " + lower(extractBefore(sizeDesc, 2)) + ...
            extractAfter(sizeDesc, 1) + " " + typeName;
    elseif strlength(typeName) > 0
        desc = desc + ": " + typeName;
    end
    desc = desc + ".";
end

function expanded = expandName(name)
%expandName Convert a camelCase or snake_case parameter name to words.
%   windowSize -> window size, num_points -> number of points, noisyURL ->
%   noisy URL. Acronyms and one-character names are left as they are.

    % Word boundaries: lower or digit to upper (windowSize), the last
    % capital of an acronym before a word (URLString), and underscores.
    words = regexprep(name, "([a-z0-9])([A-Z])", "$1 $2");
    words = regexprep(words, "([A-Z])([A-Z][a-z])", "$1 $2");
    words = split(strtrim(replace(words, "_", " ")));
    words = words(strlength(words) > 0);
    if isempty(words)
        expanded = name;
        return
    end

    persistent abbreviations
    if isempty(abbreviations)
        abbreviations = dictionary(...
            ["num", "max", "min", "iter", "tol", "idx", "len", "pts", ...
             "coeff", "freq", "vel", "pos", "val", "fcn", "func"], ...
            ["number of", "maximum", "minimum", "iterations", "tolerance", ...
             "index", "length", "points", "coefficient", "frequency", ...
             "velocity", "position", "value", "function", "function"]);
    end

    % Lowercase ordinary words; keep acronyms (two or more capitals) and a
    % one-character name as written.
    for i = 1:numel(words)
        w = words(i);
        isAcronym = strlength(w) > 1 && w == upper(w) && w ~= lower(w);
        if ~isAcronym && strlength(name) > 1
            w = lower(w);
        end
        if isKey(abbreviations, w)
            w = abbreviations(w);
        end
        words(i) = w;
    end
    expanded = strjoin(words, " ");
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
