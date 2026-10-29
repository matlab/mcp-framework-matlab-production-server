function schema = parameterObject(properties, required, kind)
%parameterObject The inputSchema or outputSchema of a tool.
%   schema = parameterObject(properties, required, kind) is the object
%   schema with one property per parameter, PROPERTIES; the names of the
%   REQUIRED ones; and minProperties and maxProperties from the parameters'
%   ParameterKinds, KIND. With no parameters it is {"type":"object"}. Both
%   schema paths use this.

% Copyright 2026 The MathWorks, Inc.

    schema.type = "object";
    if isstruct(properties) && ~isempty(fieldnames(properties))
        schema.properties = properties;
        schema.required = required;
        [schema.minProperties, schema.maxProperties] = ...
            prodserver.mcp.internal.ParameterKind.NargRange(kind);
    end
end
