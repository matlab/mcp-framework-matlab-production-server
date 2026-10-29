function [w, data] = wrapperOf(schema)
%wrapperOf The invertible wrapper in a parameter's schema.
%   w = wrapperOf(schema) is the generic wrapper SCHEMA publishes: SCHEMA
%   itself, or the wrapper alternative of an anyOf that also lists the bare
%   forms (see prodserver.mcp.jsonrpc.allowBareForms). Any other schema is
%   returned as it is. For tests that look at the wrapper's data or tag.
%
%   [w, data] = wrapperOf(schema) also returns the schema of its data
%   without the "NaN", "Inf" and "-Inf" alternative the published wrapper
%   adds for numbers (see wrapperAlternatives), and without the one-element
%   array a scalar's data is (see wrapInvertible): what the parameter's
%   declaration or examples describe.

% Copyright 2026 The MathWorks, Inc.

    [published, ~, wrapped] = prodserver.mcp.jsonrpc.bareOrWrapped(schema);
    w = schema;
    if published
        w = wrapped;
    end
    if nargout > 1
        data = [];
        if prodserver.mcp.internal.hasField(w, "properties.data")
            data = withoutSpecialFloats(w.properties.data);
            if isfield(data, 'items')
                data.items = withoutSpecialFloats(data.items);
            end
            if isOneElement(data)
                data = data.items;
            end
        end
    end
end

function s = withoutSpecialFloats(s)
    alts = prodserver.mcp.jsonrpc.schemaAlternatives(s);
    if numel(alts) == 2 && isfield(alts{2}, 'enum') && ...
            isequal(string(alts{2}.enum(:))', prodserver.mcp.MCPConstants.SpecialFloatText)
        s = alts{1};
    end
end

function tf = isOneElement(s)
% The array of exactly one element wrapInvertible makes of a scalar's data.
    tf = isstruct(s) && isscalar(s) && isfield(s, 'items') && ...
        isfield(s, 'minItems') && isfield(s, 'maxItems') && ...
        isequal(s.minItems, 1) && isequal(s.maxItems, 1);
end
