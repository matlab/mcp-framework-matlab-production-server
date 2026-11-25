function [bare, wrapped] = wrapperAlternatives(schema)
%wrapperAlternatives The forms a value of a wrapped parameter may take.
%   [bare, wrapped] = wrapperAlternatives(schema) returns the forms
%   wire_encoding_rules.txt allows for a parameter whose schema is the
%   generic wrapper (see isGenericWrapper):
%
%     bare     The bare values allowed in place of the wrapper, as a cell
%              column: a number (or "NaN", "Inf", "-Inf"), integer, string,
%              boolean or scalar struct. A bare value is the one element
%              of the wrapper's data, so its form is the data element's
%              schema, with every constraint a %#schema put there. A scalar
%              struct's form keeps only the element's type and required
%              fields, because each of its fields is wire-encoded. If that
%              schema lists alternatives (anyOf), each is a bare form; if
%              it doesn't constrain them at all, as for a parameter no
%              example exercised, any bare value is allowed. Empty if the
%              element has no schema of a single type, or if the data must
%              have more than one element (minItems), which no bare value
%              does.
%     wrapped  The wrapper, with "NaN", "Inf" and "-Inf" allowed among
%              numeric data, and without its description and annotation.
%
%   "NaN", "Inf" and "-Inf" are allowed, bare or among the data, only where
%   the element's constraints admit the values they stand for: none with
%   an enum, a const or a multipleOf, Inf only without a maximum, -Inf only
%   without a minimum, NaN only with neither.
%
%   Any of them may be sent, so a schema accepting them all is
%   struct('anyOf', {[bare; {wrapped}]}). Not oneOf: a scalar struct's bare
%   form and the wrapper are both objects.

% Copyright 2026 The MathWorks, Inc.

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
    special = specialFloats(element);
    if elementType == "" && isUnconstrained(element)
        bare = {struct()};
    elseif elementType == "" && isstruct(element) && isscalar(element) && ...
            isfield(element, 'anyOf')
        bare = prodserver.mcp.jsonrpc.schemaAlternatives(element);
        if any(cellfun(@(b) isstruct(b) && isfield(b, 'type') && ...
                isequal(string(b.type), "number"), bare))
            bare = [bare(:); special];
        end
    elseif elementType == ""
        bare = {};
    elseif elementType == "number"
        bare = [{element}; special];
    elseif elementType == "object"
        % The element's properties describe the fields as plain JSON, but
        % each field of a bare struct is itself wire-encoded, so they don't
        % apply to it.
        bare = {rmfield(element, setdiff(fieldnames(element), ...
            {'type', 'required'}))};
    else
        bare = {element};
    end
    if isstruct(data) && isscalar(data) && isfield(data, 'minItems') && ...
            data.minItems > 1
        bare = {};
    end

    wrapped = schema;
    wrapped = rmfield(wrapped, intersect(fieldnames(wrapped), ...
        {'description', 'annotation'}));
    if elementType == "number" && ~isempty(special)
        if isfield(data, 'items')
            data.items = struct('anyOf', {[{data.items}; special]});
        else
            data = struct('anyOf', {[{data}; special]});
        end
    end
    wrapped.properties.data = data;
end

function special = specialFloats(element)
% The schema of the strings "NaN", "Inf" and "-Inf" that ELEMENT's
% constraints admit, as a cell holding it, or {} if they admit none.
    import prodserver.mcp.MCPConstants
    text = MCPConstants.SpecialFloatText;
    keep = true(size(text));
    has = @(f) isstruct(element) && isscalar(element) && any(isfield(element, f));
    if has(["enum" "const" "multipleOf"])
        keep(:) = false;
    end
    if has(["minimum" "exclusiveMinimum"])
        keep(text == MCPConstants.NaNText | text == MCPConstants.NegInfText) = false;
    end
    if has(["maximum" "exclusiveMaximum"])
        keep(text == MCPConstants.NaNText | text == MCPConstants.InfText) = false;
    end
    special = {};
    if any(keep)
        special = {struct('type', "string", 'enum', {num2cell(text(keep)')})};
    end
end

function tf = isUnconstrained(schema)
% A schema that allows any value: only annotations, no keywords that
% constrain.
    annotations = {'description', 'title', 'examples'};
    tf = isstruct(schema) && isscalar(schema) && ...
        all(ismember(fieldnames(schema), annotations));
end
