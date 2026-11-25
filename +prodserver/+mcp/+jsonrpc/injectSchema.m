function [d, replaced] = injectSchema(d, userSchema, name, encoding)
%injectSchema Apply a parameter's %#schema to its generated schema.
%   [d, replaced] = injectSchema(d, userSchema, name) sets each property
%   of USERSCHEMA.schema, at any depth, in schema D. If USERSCHEMA.inject
%   is SchemaInjection.Replace, D is replaced rather than added to, and
%   REPLACED is true. NAME names the parameter in messages.
%
%   [d, replaced] = injectSchema(d, userSchema, name, encoding) also lets,
%   under ENCODING JSON, a %#schema that adds a union at the top -- anyOf
%   or oneOf, with no type -- replace the generated type: beside it, the
%   union could only narrow it, so "type": "array" would still refuse the
%   number a union of a number and an array allows. The generated
%   keywords for arrays (items, minItems, maxItems) stay: they constrain
%   only arrays. Under the invertible encoding the schema describes the
%   wrapper's data, which is always an array, so its type stays.
%
%   It is an error, prodserver:mcp:SchemaConflict, for the result to have
%   a scalar type and also maxItems or items: the %#schema contradicts the
%   argument block's size.

% Copyright 2026 The MathWorks, Inc.

    replaced = userSchema.inject == prodserver.mcp.internal.SchemaInjection.Replace;
    if replaced
        d = struct();
    end

    user = userSchema.schema;
    if ~replaced && nargin > 3 && encoding == prodserver.mcp.WireEncoding.JSON && ...
            isstruct(user) && ~isfield(user, 'type') && ...
            (isfield(user, 'anyOf') || isfield(user, 'oneOf')) && isfield(d, 'type')
        d = rmfield(d, 'type');
    end

    for p = string(fieldnames(user))'
        [pth, val] = prodserver.mcp.internal.nestedFieldValues(user, p);
        for f = 1:numel(pth)
            d = setfield(d, pth{f}{:}, val{f}); %#ok<SFLD>
        end
    end

    % A list of types is scalar only if it doesn't include "array".
    if isfield(d, 'type') && ~any(strcmpi(string(d.type), "array"))
        for keyword = ["maxItems" "items"]
            if isfield(d, keyword)
                error("prodserver:mcp:SchemaConflict", "%s", ...
                    conflict(name, keyword, d.type, userSchema.schema));
            end
        end
    end
end

function msg = conflict(name, keyword, type, user)
% Say which of the %#schema, USER, and the argument block's generated
% schema declared the scalar TYPE and which the array KEYWORD.
    types = strjoin("""" + string(type(:)') + """", ", ");
    if isscalar(string(type))
        types = "the type " + types + ", which excludes";
    else
        types = "the types " + types + ", which exclude";
    end
    fromUser = @(f) isstruct(user) && isfield(user, f);
    if fromUser(keyword) && fromUser('type')
        msg = sprintf("Parameter '%s': %%#schema declares %s, for an " + ...
            "array, but also %s arrays. These are " + ...
            "incompatible.", name, keyword, types);
    elseif fromUser(keyword)
        msg = sprintf("Parameter '%s': %%#schema declares %s, for an " + ...
            "array, but the argument block declares a scalar. These are " + ...
            "incompatible.", name, keyword);
    else
        msg = sprintf("Parameter '%s': %%#schema declares %s " + ...
            "arrays, but the argument block allows an array. " + ...
            "These are incompatible.", name, types);
    end
end
