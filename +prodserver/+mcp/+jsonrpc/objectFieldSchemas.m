function fields = objectFieldSchemas(schema, v)
%objectFieldSchemas The schemas of a struct's fields under a schema.
%   fields = objectFieldSchemas(schema) is a struct with a field for each
%   property SCHEMA describes for a struct, or for an array of structs: its
%   properties, or its items'. It is struct() if SCHEMA describes none.
%
%   Where SCHEMA lists alternatives (anyOf or oneOf), as the example path
%   writes an output whose example calls returned structs with different
%   fields, or of different shapes, the fields are those of every
%   alternative that describes structs, and each field's schema is the one
%   they give it, or an anyOf of the different ones (anyOfSchema). So each
%   field is written, and read back, by its own value: one alternative may
%   describe a field another doesn't, or give it no array where another
%   does.
%
%   fields = objectFieldSchemas(schema, v) is the fields of the struct V:
%   by those alternatives that fit its shape -- one value for a scalar
%   struct, an array for a struct array -- if any do, so that a field takes
%   the form an alternative V matches gives it. Under anyOf [array of
%   {a: number}, {a: array of number}], a scalar struct's a is an array. A
%   field none of those describes has the schema the others give it: they
%   leave it unconstrained, so its value -- "Inf" -- may follow another's.
%
%   plainJSONValue writes a struct's fields by these schemas, and
%   decodeJSONValues reads them back by the same ones.

% Copyright 2026 The MathWorks, Inc.

    if nargin < 2
        fields = merged(schema);
        return
    end
    fields = merged(fitting(schema, v));
    every = merged(schema);
    for f = string(fieldnames(every))'
        if ~isfield(fields, f)
            fields.(f) = every.(f);
        end
    end
end

function fields = merged(schema)
% The fields of every alternative in SCHEMA, each by the schema they give
% it, or an anyOf of the different ones.
    fields = struct();
    props = collect(schema, {});
    if isempty(props)
        return
    end
    if isscalar(props)
        fields = props{1};
        return
    end
    names = {};
    for k = 1:numel(props)
        names = [names; setdiff(fieldnames(props{k}), names, "stable")]; %#ok<AGROW>
    end
    for k = 1:numel(names)
        f = names{k};
        each = {};
        for j = 1:numel(props)
            if isfield(props{j}, f)
                each{end+1} = props{j}.(f); %#ok<AGROW>
            end
        end
        fields.(f) = prodserver.mcp.jsonrpc.anyOfSchema(each);
    end
end

function schema = fitting(schema, v)
% SCHEMA with only those of its alternatives whose shape fits V: one value
% (a type with no array) for a scalar, an array for any other. SCHEMA as it
% is if it lists no alternatives, or none fits.
    if ~isstruct(schema) || ~isscalar(schema)
        return
    end
    if isfield(schema, 'anyOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema);
    elseif isfield(schema, 'oneOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema, "oneOf");
    else
        return
    end
    fits = false(size(alts));
    for k = 1:numel(alts)
        a = alts{k};
        if isstruct(a) && isscalar(a) && isfield(a, 'type')
            types = string(a.type);
            if isscalar(v)
                fits(k) = ~any(types == "array");
            else
                fits(k) = all(types == "array");
            end
        end
    end
    % Of those, the ones V's fields can satisfy (mayHoldStruct), if any:
    % under anyOf [{a, b required}, {a: array}], struct('a',7) is the
    % second's, {"a":[7]}. If no one-value alternative may hold a scalar
    % struct, but an array may, the array's, as plainJSONValue sends it,
    % [{...}], and as jsondecode reads that back: one struct.
    if isstruct(v)
        names = string(fieldnames(v));
        held = cellfun(@(a) prodserver.mcp.jsonrpc.mayHoldStruct(a, names), alts);
        arrays = cellfun(@(a) isstruct(a) && isscalar(a) && isfield(a, 'type') && ...
            all(string(a.type) == "array"), alts);
        if any(fits & held)
            fits = fits & held;
        elseif isscalar(v) && any(arrays & held)
            fits = arrays & held;
        end
    end
    if any(fits)
        schema = struct('anyOf', {alts(fits)});
    end
end

function props = collect(s, props)
% The properties of each schema in S that describes structs, appended to
% PROPS: S's own, its items', or its alternatives'.
    if ~isstruct(s) || ~isscalar(s)
        return
    end
    if isfield(s, 'anyOf') || isfield(s, 'oneOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(s);
        if isempty(alts)
            alts = prodserver.mcp.jsonrpc.schemaAlternatives(s, "oneOf");
        end
        for k = 1:numel(alts)
            props = collect(alts{k}, props);
        end
    elseif isfield(s, 'type') && all(string(s.type) == "array")
        if isfield(s, 'items')
            props = collect(s.items, props);
        end
    elseif isfield(s, 'properties') && isstruct(s.properties) && ...
            isscalar(s.properties)
        props{end+1} = s.properties;
    end
end
