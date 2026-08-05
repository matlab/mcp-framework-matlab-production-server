function mustBeJsonSchemaType(x)
% mustBeJsonSchemaType Error if X is not a known JSON schema type.

% Copyright 2025-2026 The MathWorks, Inc.

    if prodserver.mcp.validation.isJsonSchemaType(x) == false
        if ischar(x)== false && isstring(x) == false
            x = "object of type " + class(x);
        end
        throwAsCaller(MException("prodserver:mcp:InvalidJSONSchemaType", ...
            "Invalid JSON schema type: %s.", x));
    end
end
