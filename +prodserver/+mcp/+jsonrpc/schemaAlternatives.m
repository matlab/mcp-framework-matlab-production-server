function alts = schemaAlternatives(schema, keyword)
%schemaAlternatives The alternatives a schema lists, as a cell column.
%   alts = schemaAlternatives(schema) is SCHEMA's anyOf, as a cell column
%   of schemas, or {} if it has none. jsondecode makes an anyOf whose
%   alternatives have the same fields a struct array, and one whose don't a
%   cell; this is the same for both.
%
%   alts = schemaAlternatives(schema, keyword) reads KEYWORD instead, such
%   as "oneOf".

% Copyright 2026 The MathWorks, Inc.

    arguments
        schema
        keyword (1,1) string = "anyOf"
    end

    alts = {};
    if isstruct(schema) && isscalar(schema) && isfield(schema, keyword)
        alts = schema.(keyword);
        if isstruct(alts)
            alts = num2cell(alts);
        end
        alts = reshape(alts, [], 1);
    end
end
