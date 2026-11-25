function tf = isNonFiniteNumberSchema(schema)
%isNonFiniteNumberSchema True for the schema of a number that may be NaN or Inf.
%   tf = isNonFiniteNumberSchema(schema) is true if SCHEMA allows a number,
%   null and a string matching MCPConstants.InfTextPattern, as
%   allowNonFiniteNumbers makes a floating-point output's under plain
%   JSON, and allows no array. plainJSONValue writes NaN as null and Inf
%   and -Inf as text where it is; decodeJSONValues reads them back.

% Copyright 2026 The MathWorks, Inc.

    tf = false;
    if ~isstruct(schema) || ~isscalar(schema) || ~isfield(schema, 'type') || ...
            ~isfield(schema, 'pattern')
        return
    end
    types = string(schema.type);
    tf = all(ismember(["number" "null" "string"], types)) && ...
        ~any(types == "array") && ...
        isequal(string(schema.pattern), prodserver.mcp.MCPConstants.InfTextPattern);
end
