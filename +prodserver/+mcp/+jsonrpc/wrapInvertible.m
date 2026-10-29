function schema = wrapInvertible(schema, tag)
%wrapInvertible Wrap a parameter's schema in the invertible envelope.
%   schema = wrapInvertible(schema) returns the type, size and data wrapper
%   of wireEncodingArgTemplate.json with SCHEMA as the schema of its data:
%   the published schema of a parameter plain JSON describes, under
%   Invertible encoding. SCHEMA's description, its schema record and its
%   x-call-by, if it has them, move to the wrapper, where the LLM and
%   externalization look for them.
%
%   schema = wrapInvertible(schema, tag) also gives the wrapper's "type"
%   field the schema TAG (see wrapperTypeSchema), such as
%   {"enum":["double"]}. By default any string will do.
%
%   A schema of wireTypeSchema's is already a whole encoded value; it takes
%   only the annotation, MCPConstants.InvertibleAnnotation.

% Copyright 2026 The MathWorks, Inc.

    persistent template
    if isempty(template)
        % JSON, for readability. Plain, so it decodes without ambiguity.
        template = jsondecode(prodserver.mcp.internal.readUTF8(fullfile( ...
            fileparts(mfilename("fullpath")), "wireEncodingArgTemplate.json")));
        % The constant is the one annotation; the file's copy only holds
        % its place.
        template.annotation = prodserver.mcp.MCPConstants.InvertibleAnnotation;
    end

    wrapper = template;
    for f = ["schema", "description", prodserver.mcp.jsonrpc.SchemaCallBy.fieldName]
        if isfield(schema, f)
            wrapper.(f) = schema.(f);
            schema = rmfield(schema, f);
        end
    end
    if nargin > 1 && ~isempty(tag)
        wrapper.properties.type = tag;
    end
    % A wrapper's data is always a flat array, even of one element
    % (wire_encoding_rules.txt), so a scalar's schema describes the one
    % element. Exactly one: externalization counts it (countSchemaItems).
    if isScalarSchema(schema)
        schema = struct('type', "array", 'items', schema, ...
            'minItems', 1, 'maxItems', 1);
    end
    wrapper.properties.data = schema;
    schema = wrapper;
end

function tf = isScalarSchema(schema)
% A schema with a single type that isn't an array: a scalar's. Not one
% with no type, which allows anything, arrays included. On the declared
% path the type is still the MATLAB class (see argumentDeclaration), and a
% cell's data is already the array of its elements. cell is the only
% MATLAB class whose data is an array: a class added to the wire encoding
% whose data is too must be added to that list, or its data becomes an
% array of one.
    tf = isstruct(schema) && isscalar(schema) && isfield(schema, 'type') && ...
        (ischar(schema.type) || (isstring(schema.type) && isscalar(schema.type))) && ...
        ~ismember(string(schema.type), ["array" "cell"]);
end
