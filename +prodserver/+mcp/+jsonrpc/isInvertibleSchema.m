function tf = isInvertibleSchema(schema)
%isInvertibleSchema True for the schema of an invertibly encoded value.
%   tf = isInvertibleSchema(schema) is true if SCHEMA carries the
%   annotation every schema of the invertible encoding has
%   (MCPConstants.InvertibleAnnotation): the generic wrapper of
%   wrapInvertible, and a whole-value schema of wireTypeSchema's. To tell
%   them apart, see isGenericWrapper.

% Copyright 2026 The MathWorks, Inc.

    tf = isstruct(schema) && isscalar(schema) && isfield(schema, 'annotation') && ...
        isequal(string(schema.annotation), prodserver.mcp.MCPConstants.InvertibleAnnotation);
end
