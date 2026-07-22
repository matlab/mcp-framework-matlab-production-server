function mustBeJsonSchemaType(x)
% mustBeJsonSchemaType Error if X is not a known JSON schema type.
    if prodserver.mcp.validation.isJsonSchemaType(x) == false
        if ischar(x)== false && isstring(x) == false
            x = "object of type " + class(x);
        end
        error("prodserver:mcp:InvalidJSONSchemaType", ...
            "Invalid JSON schema type: %s.", x);
    end
end
