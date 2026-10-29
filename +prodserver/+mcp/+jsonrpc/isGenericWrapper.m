function tf = isGenericWrapper(schema)
%isGenericWrapper True for the schema of the type, size and data wrapper.
%   tf = isGenericWrapper(schema) is true if SCHEMA is the envelope of
%   wireEncodingArgTemplate.json, which wraps the schema of a parameter
%   plain JSON describes. A value of such a parameter may also be sent bare
%   (see wrapperAlternatives).
%
%   It is false for a schema of wireTypeSchema's: one for a class plain JSON
%   can't describe, which lists its own forms and fixes its type --
%   datetime, duration, categorical, table or timetable. The generic
%   wrapper's type may be limited too (see wrapperTypeSchema), but only to
%   classes plain JSON describes.

% Copyright 2026 The MathWorks, Inc.

    import prodserver.mcp.internal.hasField
    import prodserver.mcp.internal.Constants
    % A schema of wireTypeSchema's names exactly one of its classes; a
    % generic wrapper's tag may list them among many (see wrapperTypeSchema).
    % Every wrapper has a type as well as data; an object that has only
    % data is some other object.
    tf = isstruct(schema) && isscalar(schema) && ...
        hasField(schema, "properties.data") && ...
        hasField(schema, "properties.type");
    if tf
        c = tagClasses(schema.properties.type);
        tf = ~(isscalar(c) && ismember(c, ...
            [Constants.ConvertedClasses Constants.InvertibleClasses]));
    end
end

function c = tagClasses(tag)
% The classes a type field's schema allows: an enum's, or a const's.
    c = string.empty;
    if isstruct(tag) && isfield(tag, 'enum')
        c = string(tag.enum);
    elseif isstruct(tag) && isfield(tag, 'const')
        c = string(tag.const);
    end
end
