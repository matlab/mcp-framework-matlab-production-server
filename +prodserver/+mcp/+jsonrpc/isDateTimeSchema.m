function tf = isDateTimeSchema(schema)
%isDateTimeSchema True for the schema of ISO 8601 date-time text.
%   tf = isDateTimeSchema(schema) is true if SCHEMA has
%   "format": "date-time" (MCPConstants.DateTimeFormat), as a datetime's
%   schema does under plain JSON (jsonTimeSchema) and a bare datetime's
%   under the invertible encoding (wireTypeSchema). decodeJSONValues
%   converts such values; the validator checks them.

% Copyright 2026 The MathWorks, Inc.

    tf = isstruct(schema) && isscalar(schema) && isfield(schema, 'format') && ...
        isequal(string(schema.format), prodserver.mcp.MCPConstants.DateTimeFormat);
end
