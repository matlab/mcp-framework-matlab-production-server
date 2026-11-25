function schema = allowNonFiniteNumbers(schema)
%allowNonFiniteNumbers Let the numbers in an output's schema be NaN or Inf.
%   schema = allowNonFiniteNumbers(schema) changes each "type": "number" in
%   SCHEMA, at any depth -- a scalar's, an array's items, a struct's
%   fields, the alternatives of anyOf, oneOf and allOf -- to
%
%     "type": ["number", "null", "string"], "pattern": "^-?Inf$"
%
%   Plain JSON has no NaN, Inf or -Inf. A tool's floating-point output
%   writes NaN as null and Inf and -Inf as the text "Inf" and "-Inf" (see
%   plainJSONValue), which the pattern, constraining only strings, allows
%   and nothing else. So a client that checks the result against the
%   output schema, as MCP recommends, accepts it, and decodeJSONValues
%   reads the values back. isNonFiniteNumberSchema recognizes the result.
%   Integers can't be NaN or Inf, so "integer" is left alone, as are the
%   values of enum, const, default and examples, and a number schema that
%   already has a pattern of its own.

% Copyright 2026 The MathWorks, Inc.

    if iscell(schema)
        for k = 1:numel(schema)
            schema{k} = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(schema{k});
        end
        return
    end
    if ~isstruct(schema)
        return
    end
    if isscalar(schema)
        schema = allowOne(schema);
    else
        % Alternatives jsondecode stacked: a pattern added to some would
        % leave them with different fields, so they become a cell.
        schema = cellfun(@allowOne, num2cell(schema(:)), UniformOutput=false);
    end
end

function s = allowOne(s)
    if isfield(s, 'type') && (ischar(s.type) || (isstring(s.type) && isscalar(s.type))) ...
            && string(s.type) == "number" && ~isfield(s, 'pattern')
        s.type = {"number"; "null"; "string"};
        s.pattern = prodserver.mcp.MCPConstants.InfTextPattern;
    end
    for f = ["items" "additionalProperties" "anyOf" "oneOf" "allOf"]
        if isfield(s, f)
            s.(f) = prodserver.mcp.jsonrpc.allowNonFiniteNumbers(s.(f));
        end
    end
    if isfield(s, 'properties') && isstruct(s.properties) && isscalar(s.properties)
        for p = string(fieldnames(s.properties))'
            s.properties.(p) = prodserver.mcp.jsonrpc.allowNonFiniteNumbers( ...
                s.properties.(p));
        end
    end
end
