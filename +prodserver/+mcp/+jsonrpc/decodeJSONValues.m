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
%
%   Other values are unchanged. Under anyOf or oneOf, the alternatives
%   whose JSON type fits the value are tried in order, and the first that
%   converts it wins. A value that can't be converted -- text that isn't an
%   ISO 8601 date-time, or an array mixing time zones -- leaves msg
%   describing it, starting with NOUN and the value's name; otherwise msg
%   is "".
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
    for name = string(fieldnames(values))'
        if isfield(props, name)
            [v, msg] = decode(values.(name), props.(name), name);
            if strlength(msg) > 0
                msg = noun + " " + msg;
                return
            end
            values.(name) = v;
        end
    end
end

function [v, msg] = decode(v, s, where)
    msg = "";
    if ~isstruct(s) || ~isscalar(s)
        return
    end
    if isfield(s, 'anyOf') || isfield(s, 'oneOf')
        [v, msg] = decodeAlternatives(v, s, where);
    elseif isDateTime(s)
        [v, msg] = toDatetime(v, where);
    elseif isDuration(s)
        v = toDuration(v);
    elseif hasType(s, "array") && isfield(s, 'items') && isstruct(s.items)
        item = s.items;
        if isDateTime(item)
            [v, msg] = toDatetimeArray(v, where);
        elseif isDuration(item) && isnumeric(v)
            % An array: [] is an empty one, not null.
            v = seconds(v);
        elseif isDuration(item)
            v = toDuration(v);
        elseif isstruct(v)
            for k = 1:numel(v)
                [e, msg] = decode(v(k), item, where + "(" + k + ")");
                if strlength(msg) > 0, return, end
                v(k) = e;
            end
        elseif iscell(v)
            for k = 1:numel(v)
                [v{k}, msg] = decode(v{k}, item, where + "(" + k + ")");
                if strlength(msg) > 0, return, end
            end
        end
    elseif isfield(s, 'properties') && isstruct(s.properties) && ...
            isstruct(v) && isscalar(v)
        for f = intersect(string(fieldnames(v))', string(fieldnames(s.properties))')
            [v.(f), msg] = decode(v.(f), s.properties.(f), where + "." + f);
            if strlength(msg) > 0, return, end
        end
    end
end

function [v, msg] = decodeAlternatives(v, s, where)
% The first alternative that fits V and converts it. One that fits but
% can't convert reports why, unless another converts V or accepts it as it
% is.
    if isfield(s, 'anyOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(s);
    else
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(s, "oneOf");
    end
    msg = "";
    accepted = false;
    for k = 1:numel(alts)
        if ~fitsType(v, alts{k})
            continue
        end
        [d, m] = decode(v, alts{k}, where);
        if strlength(m) > 0
            if strlength(msg) == 0, msg = m; end
        elseif ~isequaln(d, v)
            v = d;
            msg = "";
            return
        else
            accepted = true;
        end
    end
    if accepted
        msg = "";
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

function tf = hasType(s, t)
    tf = isfield(s, 'type') && any(string(s.type) == t);
end
