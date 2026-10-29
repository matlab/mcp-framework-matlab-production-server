function [d, replaced] = injectSchema(d, userSchema, name)
%injectSchema Apply a parameter's %#schema to its generated schema.
%   [d, replaced] = injectSchema(d, userSchema, name) sets each property
%   of USERSCHEMA.schema, at any depth, in schema D. If USERSCHEMA.inject
%   is SchemaInjection.Replace, D is replaced rather than added to, and
%   REPLACED is true. NAME names the parameter in messages.
%
%   It is an error, prodserver:mcp:SchemaConflict, for the result to have
%   a scalar type and also maxItems or items: the %#schema contradicts the
%   argument block's size.

% Copyright 2026 The MathWorks, Inc.

    replaced = userSchema.inject == prodserver.mcp.internal.SchemaInjection.Replace;
    if replaced
        d = struct();
    end

    for p = string(fieldnames(userSchema.schema))'
        [pth, val] = prodserver.mcp.internal.nestedFieldValues(userSchema.schema, p);
        for f = 1:numel(pth)
            d = setfield(d, pth{f}{:}, val{f}); %#ok<SFLD>
        end
    end

    if isfield(d, 'type') && ~strcmpi(d.type, "array")
        for keyword = ["maxItems" "items"]
            if isfield(d, keyword)
                error("prodserver:mcp:SchemaConflict", ...
                    "Parameter '%s': %%#schema declares %s but argument " + ...
                    "block declares scalar. These are incompatible.", ...
                    name, keyword);
            end
        end
    end
end
