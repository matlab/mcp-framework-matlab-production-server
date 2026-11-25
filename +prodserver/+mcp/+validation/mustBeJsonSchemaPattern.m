function mustBeJsonSchemaPattern(x)
% mustBeJsonSchemaPattern Error if X is not a JSON Schema pattern.
%   See isJsonSchemaPattern.

% Copyright 2026 The MathWorks, Inc.

    [tf, reason] = prodserver.mcp.validation.isJsonSchemaPattern(x);
    if ~tf
        if ischar(x) || (isstring(x) && isscalar(x))
            x = """" + string(x) + """";
        else
            x = "object of type " + class(x);
        end
        throwAsCaller(MException("prodserver:mcp:InvalidJsonSchemaPattern", ...
            "Invalid JSON Schema pattern %s: %s", x, reason));
    end
end
