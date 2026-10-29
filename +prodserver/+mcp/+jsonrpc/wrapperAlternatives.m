function [bare, wrapped] = wrapperAlternatives(schema)
%wrapperAlternatives The forms a value of a wrapped parameter may take.
%   [bare, wrapped] = wrapperAlternatives(schema) returns the forms
%   wire_encoding_rules.txt allows for a parameter whose schema is the
%   generic wrapper (see isGenericWrapper):
%
%     bare     The bare values allowed in place of the wrapper, as a cell
%              column: a number (or "NaN", "Inf", "-Inf"), integer, string,
%              boolean or scalar struct. If the elements' schema lists
%              alternatives (anyOf), each is a bare form; if it doesn't
%              constrain them at all, as for a parameter no example
%              exercised, any bare value is allowed. Otherwise empty.
%     wrapped  The wrapper, with "NaN", "Inf" and "-Inf" allowed among
%              numeric data, and without its description and annotation.
%
%   Any of them may be sent, so a schema accepting them all is
%   struct('anyOf', {[bare; {wrapped}]}). Not oneOf: a scalar struct's bare
%   form and the wrapper are both objects.

% Copyright 2026 The MathWorks, Inc.

    special = struct('type', "string", 'enum', ...
        {num2cell(prodserver.mcp.MCPConstants.SpecialFloatText(:))});

    data = schema.properties.data;
    element = data;
    if isstruct(data) && isscalar(data) && isfield(data, 'items')
        element = data.items;
    end
    elementType = "";
    if isstruct(element) && isscalar(element) && isfield(element, 'type') && ...
            (ischar(element.type) || (isstring(element.type) && isscalar(element.type)))
        elementType = string(element.type);
    end
    if elementType == "" && isUnconstrained(element)
        bare = {struct()};
    elseif elementType == "" && isstruct(element) && isscalar(element) && ...
            isfield(element, 'anyOf')
        bare = prodserver.mcp.jsonrpc.schemaAlternatives(element);
        if any(cellfun(@(b) isstruct(b) && isfield(b, 'type') && ...
                isequal(string(b.type), "number"), bare))
            bare{end+1} = special;
        end
    elseif elementType == ""
        bare = {};
    elseif elementType == "number"
        bare = {struct('type', "number"); special};
    else
        bare = {struct('type', elementType)};
    end

    wrapped = schema;
    wrapped = rmfield(wrapped, intersect(fieldnames(wrapped), ...
        {'description', 'annotation'}));
    if elementType == "number" && isfield(data, 'items')
        data.items = struct('anyOf', {{data.items; special}});
    elseif elementType == "number"
        data = struct('anyOf', {{data; special}});
    end
    wrapped.properties.data = data;
end

function tf = isUnconstrained(schema)
% A schema that allows any value: only annotations, no keywords that
% constrain.
    annotations = {'description', 'title', 'examples'};
    tf = isstruct(schema) && isscalar(schema) && ...
        all(ismember(fieldnames(schema), annotations));
end
