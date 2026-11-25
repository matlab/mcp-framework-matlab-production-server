function [values, msg] = decodeJSONValues(schema, values, noun)
%decodeJSONValues Convert plain JSON values to MATLAB datetimes and
%durations.
%   [values, msg] = decodeJSONValues(schema, values, noun) walks each field
%   of VALUES (as jsondecode delivers it) together with its schema in
%   SCHEMA.properties, at any depth, and converts the values jsonTimeSchema
%   describes:
%
%     format "date-time"           ISO 8601 text -> datetime (null -> NaT)
%     x-matlab-class "duration"    seconds       -> duration (null -> NaN)
%     type ["number", "null"]      null          -> NaN
%     isNonFiniteNumberSchema      "Inf", "-Inf" -> Inf, -Inf
%     array of type "string"       text          -> string array (outputs)
%
%   jsondecode reads a member's null as [], but plain JSON writes a scalar
%   NaN as null, and Inf and -Inf as text, and allowNonFiniteNumbers lets
%   an output's numbers be either. An array holding the text, which
%   jsondecode gives as a cell, becomes the numeric array plainJSONValue
%   wrote: a vector as a column, as jsondecode gives one, and an array of
%   arrays with one row (first-dimension slice) for each.
%
%   On outputs (NOUN "Output"), an array of strings becomes the string array
%   its schema describes, whatever its length, not the cell of char (or,
%   with one element, the char) jsondecode gives. Not on arguments: a
%   %#schema may describe a cell parameter's items as strings.
%
%   Other values are unchanged. Under anyOf or oneOf, the alternatives
%   whose JSON type fits the value are tried in order, and the first that
%   converts it wins; a number's alternative claims "Inf" or "-Inf" only if
%   no other converts the text or accepts it as it is, and an array of
%   strings claims an array of nulls (NaN) only if no other accepts the
%   numbers. In an output, null
%   or [] goes to the first alternative that is an array, as an empty one:
%   plainJSONValue sends a missing scalar there as [null]. A struct's
%   fields are read by the schemas the alternatives that fit its shape
%   give them (objectFieldSchemas), as plainJSONValue writes them. A value that can't
%   be converted -- text that isn't an ISO 8601 date-time, or an array
%   mixing time zones -- leaves msg describing it, starting with NOUN and
%   the value's name; otherwise msg is "".
%
%   The server decodes a tool's arguments with its inputSchema and the noun
%   "Argument", after validating them (toolArgumentError), so that only
%   these conversions can fail. The client decodes a tool's results with
%   its outputSchema and the noun "Output".

% Copyright 2026 The MathWorks, Inc.

    arguments
        schema
        values struct
        noun (1,1) string
    end

    import prodserver.mcp.internal.hasField

    msg = "";
    if ~hasField(schema, "properties") || ~isstruct(schema.properties)
        return
    end
    props = schema.properties;
    output = noun == "Output";
    for name = string(fieldnames(values))'
        if isfield(props, name)
            [v, msg] = decode(values.(name), props.(name), name, output);
            if strlength(msg) > 0
                msg = noun + " " + msg;
                return
            end
            values.(name) = v;
        end
    end
end

function [v, msg] = decode(v, s, where, output)
    msg = "";
    if ~isstruct(s) || ~isscalar(s)
        return
    end
    if (isfield(s, 'anyOf') || isfield(s, 'oneOf')) && isstruct(v) && ...
            ~isempty(fieldnames(prodserver.mcp.jsonrpc.objectFieldSchemas(s, v)))
        % A struct's fields by the schemas the alternatives that fit its
        % shape give them, as plainJSONValue writes them: not by one
        % alternative, which may not describe a field another does.
        object.type = "object";
        object.properties = prodserver.mcp.jsonrpc.objectFieldSchemas(s, v);
        [v, msg] = decode(v, object, where, output);
    elseif isfield(s, 'anyOf') || isfield(s, 'oneOf')
        [v, msg] = decodeAlternatives(v, s, where, output);
    elseif isDateTime(s)
        [v, msg] = toDatetime(v, where);
    elseif isDuration(s)
        v = toDuration(v);
    elseif isNullableNumber(s)
        if isnumeric(v) && isempty(v)
            v = NaN;
        elseif prodserver.mcp.jsonrpc.isNonFiniteNumberSchema(s)
            v = fromInfText(v);
        end
    elseif hasType(s, "array") && isfield(s, 'items') && isstruct(s.items)
        item = s.items;
        if prodserver.mcp.jsonrpc.isNonFiniteNumberSchema(item) && ...
                (iscell(v) || ischar(v))
            v = fromInfText(v);
        elseif isDateTime(item)
            [v, msg] = toDatetimeArray(v, where);
        elseif isDuration(item) && isnumeric(v)
            % An array: [] is an empty one, not null.
            v = seconds(v);
        elseif isDuration(item)
            v = toDuration(v);
        elseif output && isPlainString(item)
            v = toStringArray(v);
        elseif isstruct(v)
            for k = 1:numel(v)
                [e, msg] = decode(v(k), item, where + "(" + k + ")", output);
                if strlength(msg) > 0, return, end
                v(k) = e;
            end
        elseif iscell(v)
            for k = 1:numel(v)
                [v{k}, msg] = decode(v{k}, item, where + "(" + k + ")", output);
                if strlength(msg) > 0, return, end
            end
        end
    elseif isfield(s, 'properties') && isstruct(s.properties) && isstruct(v)
        % A struct array too, where the examples returned one struct.
        fields = intersect(string(fieldnames(v))', string(fieldnames(s.properties))');
        for k = 1:numel(v)
            at = where;
            if ~isscalar(v)
                at = where + "(" + k + ")";
            end
            for f = fields
                [v(k).(f), msg] = decode(v(k).(f), s.properties.(f), at + "." + f, output);
                if strlength(msg) > 0, return, end
            end
        end
    end
end

function tf = isStringArray(s)
% The schema of an array of strings that are text.
    tf = isstruct(s) && isscalar(s) && hasType(s, "array") && ...
        isfield(s, 'items') && isPlainString(s.items);
end

function tf = isPlainString(s)
% The schema of a string that is text, not a date-time.
    tf = isstruct(s) && isscalar(s) && isfield(s, 'type') && ...
        isequal(string(s.type), "string") && ~isDateTime(s);
end

function v = toStringArray(v)
% A JSON array of strings, which jsondecode gives as a cell of char (null
% as []) -- of cells, one per row, for a matrix -- or, with one element, as
% char, or all null, as NaN, as the string array it describes: a vector as
% a column, as jsondecode gives numbers, null as missing. Anything else,
% such as an array that isn't all text, is left alone.
    if ischar(v)
        v = string(v);
        return
    end
    if isnumeric(v) && isempty(v)
        v = strings(0, 1);
        return
    end
    % All null: jsondecode gives NaN, in the array's shape.
    if isfloat(v) && all(isnan(v), "all")
        v = repmat(string(missing), size(v));
        return
    end
    if ~iscell(v)
        return
    end
    [flat, shape, ok] = flattenRows(nullRowsAsCells(v));
    isNull = cellfun(@(e) isnumeric(e) && isempty(e), flat);
    isText = cellfun(@(e) ischar(e) && (isrow(e) || isempty(e)), flat);
    if ~ok || ~all(isNull | isText)
        return
    end
    flat(isNull) = {''};
    d = string(flat(:));
    d(isNull) = missing;
    if ~isempty(shape)
        d = prodserver.mcp.jsonrpc.fromRowMajor(d, shape);
    end
    v = d;
end

function [v, msg] = decodeAlternatives(v, s, where, output)
% The first alternative that fits V and converts it. One that fits but
% can't convert reports why, unless another converts V or accepts it as it
% is.
%
% A number that may be Inf claims text only if no other alternative
% converts it or accepts it as it is: under anyOf [string, number], the
% text "Inf" is a string. Likewise an array of strings claims an array of
% nulls: under anyOf [number, string array], [null] is NaN.
    if isfield(s, 'anyOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(s);
    else
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(s, "oneOf");
    end
    % jsondecode gives null and [] alike as []. In an output, where an array
    % may be, it is an empty one: plainJSONValue sends a scalar NaN there
    % as [null]. Not in an argument: a client sends a missing value as
    % null, and its encoder knows no schema.
    if output && isnumeric(v) && isempty(v)
        isArray = cellfun(@(a) isstruct(a) && isscalar(a) && ...
            hasType(a, "array"), alts);
        if any(isArray)
            [v, msg] = decode(v, alts{find(isArray, 1)}, where, output);
            return
        end
    end
    % Alternatives that claim V only if no other converts it or accepts it
    % as it is: a number that may be Inf, for text; an array of strings,
    % for an array of nulls, which jsondecode gives as NaN, and which may
    % be numbers.
    later = false(size(alts));
    if ischar(v) || (isstring(v) && isscalar(v))
        later = cellfun(@prodserver.mcp.jsonrpc.isNonFiniteNumberSchema, alts);
    elseif output && isfloat(v) && ~isempty(v) && all(isnan(v), "all")
        later = cellfun(@isStringArray, alts);
    end
    [v, msg, done] = tryAlternatives(v, alts(~later), where, output);
    if ~done && any(later)
        [d, m, done] = tryAlternatives(v, alts(later), where, output);
        if done
            v = d;
            msg = "";
        elseif strlength(msg) == 0
            msg = m;
        end
    end
end

function [v, msg, done] = tryAlternatives(v, alts, where, output)
% The first of ALTS that fits V and converts it. DONE is true if one
% converts V or one accepts it as it is.
    msg = "";
    done = false;
    accepted = false;
    for k = 1:numel(alts)
        if ~fitsType(v, alts{k})
            continue
        end
        [d, m] = decode(v, alts{k}, where, output);
        if strlength(m) > 0
            if strlength(msg) == 0, msg = m; end
        elseif ~strcmp(class(d), class(v)) || ~isequaln(d, v)
            v = d;
            msg = "";
            done = true;
            return
        else
            accepted = true;
        end
    end
    if accepted
        msg = "";
        done = true;
    end
end

function tf = fitsType(v, s)
% Whether jsondecode's V could be a JSON value of the type S names. An
% alternative without a type fits anything.
    if ~isstruct(s) || ~isscalar(s) || ~isfield(s, 'type')
        tf = true;
        return
    end
    t = string(s.type);
    if ischar(v)
        kinds = "string";      % jsondecode's text, even ''
    elseif isnumeric(v) && isempty(v)
        kinds = ["null" "array"];
    elseif isfloat(v) && isscalar(v) && isnan(v)
        kinds = ["array" "number"];   % [null]: JSON has no NaN
    elseif iscell(v) || ~isscalar(v)
        kinds = "array";
    elseif isstring(v)
        kinds = "string";
    elseif islogical(v)
        kinds = "boolean";
    elseif isnumeric(v)
        kinds = ["number" "integer"];
    elseif isstruct(v)
        kinds = "object";
    else
        kinds = string.empty;
    end
    tf = any(ismember(kinds, t));
end

function [d, msg] = toDatetime(v, where)
    msg = "";
    if isnumeric(v) && isempty(v)
        d = NaT;     % null
        return
    end
    [d, ok] = prodserver.mcp.jsonrpc.parseISODateTime(v);
    if ~ok
        msg = sprintf("'%s': %s, got %s", where, ...
            prodserver.mcp.MCPConstants.DateTimeExpected, describe(v));
    end
end

function text = describe(v)
% V as the client sent it, for a message. Never fails: V may be anything
% jsondecode returns, including NaN for null.
    if ischar(v) || (isstring(v) && isscalar(v) && ~ismissing(v))
        text = "'" + string(v) + "'";
    else
        text = string(jsonencode(v));
    end
end

function [d, msg] = toDatetimeArray(v, where)
% A JSON array of date-time text arrives as a cell -- a matrix as a cell of
% cells, one per row; a single value, which satisfies an array schema, as
% text.
    msg = "";
    if isnumeric(v) && all(isnan(v), "all")
        % An empty array, or one of nulls: jsondecode makes it numeric.
        d = NaT(size(v));
        return
    end
    if ~iscell(v)
        [d, msg] = toDatetime(v, where);
        return
    end
    [v, shape, ok] = flattenRows(v);
    if ~ok
        d = NaT;
        msg = sprintf("'%s': expected an array of ISO 8601 date-times " + ...
            "with rows of equal length", where);
        return
    end
    % One parse for the whole array; null is [] and becomes NaT.
    isNull = cellfun(@(e) isnumeric(e) && isempty(e), v);
    [d, ok, zone, mixed] = prodserver.mcp.jsonrpc.parseISODateTime(v);
    bad = find(~ok & ~isNull, 1);
    if ~isempty(bad)
        d = NaT;
        msg = sprintf("'%s(%d)': %s, got %s", where, bad, ...
            prodserver.mcp.MCPConstants.DateTimeExpected, describe(v{bad}));
        return
    end
    % Every element must have the same zone -- unzoned, or one offset, Z
    % being +00:00 -- for the array to have one. A null (NaT) takes it.
    % (The invertible encoding is laxer: its tz names the zone.)
    zones = zone(ok);
    zones(ismember(zones, ["UTC" "-00:00"])) = "+00:00";
    zones = unique(zones);
    if mixed || numel(zones) > 1
        d = NaT;
        if mixed
            msg = sprintf("'%s': mixes date-times with and " + ...
                "without a time zone. Give every element a Z or an " + ...
                "offset, or none of them", where);
        else
            msg = sprintf("'%s': mixes time zones (%s). Give " + ...
                "every element the same offset", where, strjoin(zones, ", "));
        end
        return
    end
    if ~isempty(shape)
        % Row-major, as the rows nest.
        d = prodserver.mcp.jsonrpc.fromRowMajor(d, shape);
    end
end

function v = nullRowsAsCells(v)
% In a JSON array of arrays of strings, jsondecode gives a row that is all
% null as NaN, not as a cell: a cell of [], nested as the other rows are.
    if ~iscell(v) || ~any(cellfun(@iscell, v(:)))
        return
    end
    for k = 1:numel(v)
        e = v{k};
        if iscell(e)
            v{k} = nullRowsAsCells(e);
        elseif isfloat(e) && ~isempty(e) && all(isnan(e), "all")
            v{k} = nullCells(e);
        end
    end
end

function c = nullCells(e)
% The cell jsondecode gives for an array of text, in the shape of E, which
% it gave, as all null, as NaN: a vector as a column, a matrix as a column
% of its rows.
    if isvector(e)
        c = repmat({[]}, numel(e), 1);
        return
    end
    sz = size(e);
    c = cell(sz(1), 1);
    for k = 1:sz(1)
        c{k} = nullCells(reshape(e(k, :), [sz(2:end) 1]));
    end
end

function [flat, shape, ok] = flattenRows(v)
% The elements of a JSON array of arrays, in row-major order, and its
% shape. shape is empty if V doesn't nest; ok is false if its rows differ
% in length.
    ok = true;
    shape = [];
    flat = v;
    if isempty(v) || ~all(cellfun(@iscell, v(:)))
        return
    end
    flat = {};
    for k = 1:numel(v)
        [row, rowShape, ok] = flattenRows(v{k});
        if isempty(rowShape)
            rowShape = numel(row);
        end
        if ~ok || (k > 1 && ~isequal(rowShape, shape(2:end)))
            ok = false;
            return
        end
        shape = [numel(v), rowShape];
        flat = [flat, reshape(row, 1, [])]; %#ok<AGROW>
    end
    flat = flat(:);
end

function d = toDuration(v)
% jsondecode turns null into [] for a scalar and NaN inside a numeric array.
    if isnumeric(v) && isempty(v)
        v = NaN;
    end
    d = seconds(v);
end

function tf = isDateTime(s)
    tf = prodserver.mcp.jsonrpc.isDateTimeSchema(s);
end

function tf = isDuration(s)
    f = prodserver.mcp.MCPConstants.MatlabClass_Field;
    tf = isfield(s, f) && isequal(string(s.(f)), "duration");
end

function v = fromInfText(v)
% The numbers V, as jsondecode gives an array or value that may hold the
% text "Inf" or "-Inf": that text as Inf or -Inf, null ([]) as NaN. A cell
% is a JSON array: of numbers, a column; of arrays, one slice each along
% the first dimension. Anything else is left alone.
    import prodserver.mcp.MCPConstants
    if ischar(v) || (isstring(v) && isscalar(v))
        if string(v) == MCPConstants.InfText
            v = Inf;
        elseif string(v) == MCPConstants.NegInfText
            v = -Inf;
        end
        return
    end
    if ~iscell(v)
        return
    end
    e = cellfun(@fromInfText, v(:), UniformOutput=false);
    for k = 1:numel(e)
        if isnumeric(e{k}) && isempty(e{k})
            e{k} = NaN;
        end
    end
    if ~all(cellfun(@(x) isnumeric(x), e))
        return
    end
    if all(cellfun(@isscalar, e))
        v = [e{:}]';
    elseif all(cellfun(@(x) isequal(size(x), size(e{1})), e))
        % Slice k is v(k,:,...). A vector slice is a row of a matrix.
        sz = size(e{1});
        if iscolumn(e{1})
            sz = sz(1);
        end
        v = zeros([numel(e) sz 1]);
        for k = 1:numel(e)
            v(k, :) = e{k}(:)';
        end
    end
end

function tf = isNullableNumber(s)
% A scalar's schema that allows a number or null, but no array.
    tf = hasType(s, "number") && hasType(s, "null") && ~hasType(s, "array");
end

function tf = hasType(s, t)
    tf = isfield(s, 'type') && any(string(s.type) == t);
end
