function v = plainJSONValue(v, schema)
%plainJSONValue Prepare a tool output for plain JSON encoding.
%   v = plainJSONValue(v) replaces the values jsonencode would write as
%   display text, which depends on the server's locale and settings, with
%   values a client can parse anywhere:
%
%     datetime   ISO 8601 text, as the invertible encoding writes a scalar
%                datetime: 2026-01-02T03:04:05.000 when unzoned, with a Z
%                suffix in UTC, with an offset in any other zone. An
%                array in a zone other than UTC is written in UTC: a named
%                zone's offset changes with daylight saving, and an array
%                must have one zone to be read back. NaT becomes null.
%     duration   Its length in seconds.
%     timetable  A table, with the row times as its first variable.
%                (jsonencode writes a timetable as {}.)
%
%   It looks inside structs, struct arrays, cells and tables. Other values
%   are unchanged. Only plain JSON encoding needs this: the invertible
%   encoding has its own forms for these classes.
%
%   V is a member of a JSON object -- an argument, an output, or a struct
%   field -- and so is each struct field inside it. A scalar NaN there
%   becomes {NaN}, which jsonencode writes as [null]: jsondecode reads
%   null as [], but [null] as NaN. In an array, a cell or a table column,
%   null already reads back as NaN, so it is left alone.
%
%   v = plainJSONValue(v, schema) writes V in the form SCHEMA, the schema
%   published for it, describes, so that a client that checks the value
%   against the schema accepts it. Where SCHEMA is an array, a one-element
%   value is a one-element array: 7 is [7], NaN is [null], a struct is
%   [{...}]. Where it isn't, a scalar NaN is null if SCHEMA allows a
%   number or null, which a client reads back as NaN, and [null] if not,
%   as with no schema. Where SCHEMA, or its
%   items', is a number that may be NaN or Inf (isNonFiniteNumberSchema),
%   Inf and -Inf are the text "Inf" and "-Inf": [1,"Inf",null] for
%   [1 Inf NaN], with a matrix's rows as arrays, as jsonencode writes a
%   numeric matrix. allowNonFiniteNumbers makes a floating-point output's
%   schema allow them, and decodeJSONValues reads them back.
%   A struct's fields follow its properties' schemas -- under
%   alternatives, the schemas those that fit its shape give each field
%   (objectFieldSchemas) -- and a cell's elements its items'. Where SCHEMA
%   lists alternatives (anyOf or oneOf),
%   V follows the first whose shape fits it -- a scalar for a single
%   value, an array otherwise -- preferring one of V's own JSON type, or
%   for an array, one whose items are of its elements' type. A single
%   value that no one-value alternative is of the type of follows an
%   array alternative whose items are, as an array of one: "z" under
%   anyOf [array of string, number] is ["z"]. A
%   scalar NaN, NaT, NaN duration or missing string follows an array
%   alternative, if there
%   is one, as [null].
%   Where none fits, or SCHEMA is empty, V is written as without one.
%
%   A complex value is an error, prodserver:mcp:IncompatibleArgumentType:
%   plain JSON has no form for its imaginary part, and jsonencode's own
%   error doesn't say what to do about it. So is a value holding Inf or
%   -Inf, including a duration, unless SCHEMA allows their text:
%   jsonencode writes them as null, as it does NaN, so they would silently
%   arrive as NaN. So is Inf or -Inf where SCHEMA lists alternatives, and
%   a client would read the text back as a string: under anyOf [string,
%   number], the text "Inf" may be either, and is the string. And an
%   empty member where SCHEMA allows no array is
%   prodserver:mcp:EmptyScalarOutput: jsondecode reads [] as it reads
%   null, so it would arrive as NaN. That includes alternatives that
%   each allow one value, such as anyOf [string, number], unless one
%   allows null and a client reads null back as empty, as under anyOf
%   [string, null]: then the value is null.

% Copyright 2026 The MathWorks, Inc.

    if nargin < 2
        schema = [];
    end
    v = prepare(v, true, schema, "");
end

function v = prepare(v, member, schema, where)
% MEMBER is true if V is a member of a JSON object, not an array element.
% SCHEMA is V's schema, or [] if there is none. WHERE is V's place in the
% value, for messages: "" for the value itself, or such as "(2).a{3}".
    whole = schema;
    schema = alternativeFor(v, schema);
    if isa(v, "datetime")
        if ~isscalar(v) && ~isempty(v.TimeZone)
            v.TimeZone = "UTC";
        end
        v = prodserver.mcp.jsonrpc.isoDateTimeText(v);
    elseif isa(v, "duration")
        v = seconds(v);
    elseif istimetable(v)
        v = prepare(timetable2table(v), member, [], where);
    elseif istable(v)
        for name = string(v.Properties.VariableNames)
            v.(name) = prepare(v.(name), false, [], where + "." + name);
        end
    elseif isstruct(v)
        % By the whole schema: with alternatives, each field by the
        % schemas those that fit V's shape give it, as decodeJSONValues
        % reads it.
        fields = prodserver.mcp.jsonrpc.objectFieldSchemas(whole, v);
        for k = 1:numel(v)
            at = where;
            if ~isscalar(v)
                at = where + "(" + k + ")";
            end
            for f = string(fieldnames(v))'
                fs = [];
                if isfield(fields, f)
                    fs = fields.(f);
                end
                v(k).(f) = prepare(v(k).(f), true, fs, at + "." + f);
            end
        end
    elseif iscell(v)
        item = itemSchema(schema);
        for k = 1:numel(v)
            v{k} = prepare(v{k}, false, item, where + "{" + k + "}");
        end
    elseif isnumeric(v) && ~isreal(v)
        error("prodserver:mcp:IncompatibleArgumentType", ...
            "Plain JSON can't carry complex values: it has no form for " + ...
            "the imaginary part. Only the invertible wire encoding can.");
    end
    % After the conversions: a duration may be Inf seconds, or NaN.
    infinite = isfloat(v) && any(isinf(v), "all");
    if infinite && admitsInfText(schema)
        numbers = v;
        v = infText(v);
    elseif infinite
        error("prodserver:mcp:IncompatibleArgumentType", ...
            "Plain JSON can't carry Inf or -Inf: it writes them as null, " + ...
            "as it does NaN, so they would arrive as NaN. Only the " + ...
            "invertible wire encoding can.");
    end
    infiniteText = ~infinite && ~isequal(whole, schema) && ...
        ((ischar(v) && isrow(v)) || isstring(v)) && ...
        any(matches(string(v), [prodserver.mcp.MCPConstants.InfText ...
        prodserver.mcp.MCPConstants.NegInfText]), "all");
    if infiniteText
        text = string(v);
    end
    v = shaped(v, member, schema, where);
    if infinite && ~isequal(whole, schema)
        requireReadBack(numbers, v, whole);
    elseif infiniteText
        requireTextReadBack(text, v, whole);
    end
end

function requireTextReadBack(text, v, schema)
% Error unless a client reads V, which holds the text "Inf" or "-Inf", back
% as TEXT under SCHEMA, which lists alternatives. Under anyOf [array of
% number, array of string], ["Inf"] is how plain JSON sends both the number
% Inf and the text, and decodeJSONValues reads it as the number.
    wire.properties.m = schema;
    back = prodserver.mcp.jsonrpc.decodeJSONValues(wire, ...
        jsondecode(jsonencode(struct('m', {v}))), "Output");
    b = back.m;
    if iscellstr(b) || ischar(b) %#ok<ISCLSTR>
        b = string(b);
    end
    % A missing string, which plain JSON sends as null, is no string ==
    % another, but reads back as one.
    b = b(:);
    text = text(:);
    same = isstring(b) && numel(b) == numel(text) && ...
        isequal(ismissing(b), ismissing(text)) && ...
        all(b(~ismissing(b)) == text(~ismissing(text)));
    if ~same
        error("prodserver:mcp:IncompatibleArgumentType", ...
            "Plain JSON can't carry the text ""Inf"" or ""-Inf"" here: it " + ...
            "sends the numbers Inf and -Inf as that text, and the schema " + ...
            "allows them too, so a client would read it back as a " + ...
            "number. Only the invertible wire encoding can.");
    end
end

function requireReadBack(numbers, v, schema)
% Error unless a client reads V, the text form of NUMBERS, back as NUMBERS
% under SCHEMA, which lists alternatives. Under anyOf [string, number], the
% text "Inf" is the string: decodeJSONValues tries a number's alternative on
% text last, as the text may be a string. Only the server knows it isn't.
    wire.properties.m = schema;
    back = prodserver.mcp.jsonrpc.decodeJSONValues(wire, ...
        jsondecode(jsonencode(struct('m', {v}))), "Output");
    if ~(isnumeric(back.m) && numel(back.m) == numel(numbers) && ...
            isequaln(double(back.m(:)), double(numbers(:))))
        error("prodserver:mcp:IncompatibleArgumentType", ...
            "Plain JSON can't carry Inf or -Inf here: it sends them as " + ...
            "the text ""Inf"" and ""-Inf"", but the schema allows text " + ...
            "too, so a client would read them back as text. Only the " + ...
            "invertible wire encoding can.");
    end
end

function v = shaped(v, member, schema, where)
% V as SCHEMA describes it: in a one-element array where SCHEMA is an array,
% and as it is where SCHEMA is a scalar. With no schema, a member's scalar
% NaN is [null], which jsondecode reads as NaN.
    switch kindOf(schema)
        case "array"
            % A char row is one string, as a string scalar is.
            if ((isnumeric(v) || islogical(v) || isstring(v) || isstruct(v)) && ...
                    isscalar(v) && ~iscell(v)) || ...
                    (ischar(v) && (isrow(v) || isempty(v)))
                v = {v};
            end
        case "scalar"
            % jsonencode writes a scalar NaN as null. It writes an empty
            % value as [], which the schema doesn't allow, and which a
            % client reads as it reads null.
            if member && emptyValue(v)
                emptyScalarError(where);
            end
            % A client reads null back as NaN only where the schema allows
            % a number or null, as decodeJSONValues does. Elsewhere -- a
            % %#schema that replaced it with "number" -- [null], as with no
            % schema: the schema allows neither, but [null] arrives as NaN.
            if member && isfloat(v) && isscalar(v) && isnan(v) && ...
                    ~(hasType(schema, "number") && hasType(schema, "null"))
                v = {v};
            end
        otherwise
            % Likewise where every alternative is one value, as the example
            % path writes an output seen with two classes, each scalar --
            % unless one allows null, and a client reads null back as
            % empty: under anyOf [string, null], it is null, which a client
            % reads as [], but under a number's, null is NaN.
            if member && emptyValue(v) && singleValuesOnly(schema)
                if allowsNull(schema) && readsBackEmpty(schema)
                    v = NaN;    % which jsonencode writes as null
                    return
                end
                emptyScalarError(where);
            end
            if member && isfloat(v) && isscalar(v) && isnan(v)
                v = {v};
            end
    end
end

function tf = emptyValue(v)
% An empty value jsonencode writes as [], which a client reads as null.
    tf = isempty(v) && ~ischar(v) && (isnumeric(v) || islogical(v) || ...
        isstring(v) || isstruct(v));
end

function tf = singleValuesOnly(schema)
% True if SCHEMA lists alternatives, and each allows one value, no array.
    alts = {};
    if isstruct(schema) && isscalar(schema) && isfield(schema, 'anyOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema);
    elseif isstruct(schema) && isscalar(schema) && isfield(schema, 'oneOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema, "oneOf");
    end
    tf = ~isempty(alts) && all(cellfun(@(a) kindOf(a) == "scalar", alts));
end

function tf = allowsNull(schema)
% True if one of SCHEMA's alternatives allows null: its type is, or lists,
% null.
    alts = {};
    if isfield(schema, 'anyOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema);
    elseif isfield(schema, 'oneOf')
        alts = prodserver.mcp.jsonrpc.schemaAlternatives(schema, "oneOf");
    end
    tf = any(cellfun(@(a) isstruct(a) && isscalar(a) && hasType(a, "null"), alts));
end

function tf = readsBackEmpty(schema)
% True if a client reads null ([] to jsondecode) under SCHEMA back as
% empty, as decodeJSONValues does: not as NaN, which it reads null as where
% a number may be.
    wire.properties.m = schema;
    back = prodserver.mcp.jsonrpc.decodeJSONValues(wire, ...
        struct('m', {[]}), "Output");
    tf = isempty(back.m);
end

function emptyScalarError(where)
% The error for an empty value where its schema describes one value. WHERE
% is "" for the value itself, or the place of a field in it.
    why = "but its schema describes a single value, so plain JSON " + ...
        "can't send it: a client reads [] as it reads null, which is NaN.";
    if strlength(where) == 0
        error("prodserver:mcp:EmptyScalarOutput", "The value is empty, " + ...
            why + " Declare the output's size in an arguments (Output) " + ...
            "block, such as (1,:), if it may be empty.");
    end
    error("prodserver:mcp:EmptyScalarOutput", "Its field '%s' is " + ...
        "empty, " + why + " If it may be empty, add an example call " + ...
        "that returns it empty, or describe the output with a %%#schema " + ...
        "that allows an array there.", strip(where, "left", "."));
end

function tf = admitsInfText(schema)
% True if SCHEMA, or the schema of its items, is a number that may be Inf.
    tf = prodserver.mcp.jsonrpc.isNonFiniteNumberSchema(schema) || ...
        (kindOf(schema) == "array" && isfield(schema, 'items') && ...
        prodserver.mcp.jsonrpc.isNonFiniteNumberSchema(schema.items));
end

function v = infText(v)
% V with Inf and -Inf as their text. A scalar is a string; an array, a cell
% that jsonencode writes as the numeric array would be, with the text in
% place: a vector's elements, or for a matrix, a cell of its rows (slices
% along the first dimension), as jsonencode nests a numeric matrix. NaN
% stays NaN, which jsonencode writes, in a cell, as null.
    import prodserver.mcp.MCPConstants
    if isscalar(v)
        if isinf(v) && v > 0
            v = MCPConstants.InfText;
        elseif isinf(v)
            v = MCPConstants.NegInfText;
        end
        return
    end
    if isvector(v)
        c = num2cell(double(v(:)'));
        for k = find(isinf(v(:)'))
            if v(k) > 0
                c{k} = MCPConstants.InfText;
            else
                c{k} = MCPConstants.NegInfText;
            end
        end
        v = c;
        return
    end
    sz = size(v);
    c = cell(1, sz(1));
    for k = 1:sz(1)
        c{k} = infText(reshape(v(k, :), [sz(2:end) 1]));
    end
    v = c;
end

function schema = alternativeFor(v, schema)
% Where SCHEMA lists alternatives (anyOf or oneOf), the first whose kind
% fits V's shape: a scalar for a single value, an array for any other, as
% the example path writes an output seen in both shapes. SCHEMA as it is
% if it lists none, or none fits.
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
    single = (ischar(v) && (isrow(v) || isempty(v))) || ...
        (~iscell(v) && ~istabular(v) && isscalar(v));
    wanted = "array";
    if single
        wanted = "scalar";
    end
    % A scalar NaN as [null], where an array may be: a client reads null
    % as it reads [], an empty array, but [null] as NaN.
    missingValue = single && ~ischar(v) && ((isfloat(v) && isnan(v)) || ...
        (isdatetime(v) && isnat(v)) || (isduration(v) && isnan(v)) || ...
        (isstring(v) && ismissing(v)));
    if single && missingValue && any(cellfun(@(a) kindOf(a) == "array", alts))
        wanted = "array";
        single = false;
    end
    fits = cellfun(@(a) kindOf(a) == wanted, alts);
    % Of those, one of V's own JSON type -- for an array, one whose items
    % are of its elements' type -- if there is one. Only those that fit: an
    % alternative with no type -- an enum, a const -- has no kind, so it
    % never fits, and has no type to test.
    jsonType = jsonTypeOf(v);
    typed = fits;
    typed(fits) = cellfun(@(a) namesType(a, single, jsonType), alts(fits));
    if isstruct(v)
        % Of those, one V's fields may satisfy (mayHoldStruct), as
        % objectFieldSchemas chooses its fields' schemas. If no one-value
        % alternative may hold a single struct, but an array may, an
        % array of one: under anyOf [array of {a}, {a, b required}],
        % struct('a',7) is [{"a":7}].
        names = string(fieldnames(v));
        held = cellfun(@(a) prodserver.mcp.jsonrpc.mayHoldStruct(a, names), alts);
        arrays = cellfun(@(a) kindOf(a) == "array", alts);
        if any(fits & held)
            fits = fits & held;
            typed = typed & held;
        elseif single && any(arrays & held)
            schema = alts{find(arrays & held, 1)};
            return
        end
    end
    if single && ~any(typed)
        % A single value no one-value alternative is of the type of, as
        % "z" under anyOf [array of string, number], or 5 under anyOf
        % [array of number, array of string]: an array of one, under one
        % whose items are of its type, which a client reads back as V. As
        % it is, it is no value the schema allows. Not where an alternative
        % has no type -- an enum, a const, {} -- which may be V's as it is.
        untyped = cellfun(@(a) kindOf(a) == "", alts);
        arrays = cellfun(@(a) kindOf(a) == "array", alts);
        typedArray = arrays;
        typedArray(arrays) = cellfun(@(a) namesType(a, false, jsonType), alts(arrays));
        if ~any(untyped) && any(typedArray)
            schema = alts{find(typedArray, 1)};
            return
        end
    end
    if ~any(fits)
        return
    end
    if any(typed)
        schema = alts{find(typed, 1)};
    else
        schema = alts{find(fits, 1)};
    end
end

function t = jsonTypeOf(v)
% The JSON type V is written as, or each element of an array V: "" for a
% cell or a table, whose elements' types may differ.
    if iscell(v) || istabular(v)
        t = "";
    elseif isnumeric(v) || isduration(v)
        t = "number";
    elseif islogical(v)
        t = "boolean";
    elseif isstruct(v)
        t = "object";
    else
        t = "string";
    end
end

function tf = namesType(a, single, t)
% Whether the alternative A, or for an array (SINGLE false) its items, has
% the JSON type T. A number may be an integer's. A number that may be NaN
% or Inf (isNonFiniteNumberSchema) has the type string for "Inf" and
% "-Inf" only, and is no string's.
    if ~single
        if ~isfield(a, 'items') || ~isstruct(a.items) || ...
                ~isscalar(a.items) || ~isfield(a.items, 'type')
            tf = false;
            return
        end
        a = a.items;
    end
    if t == "string" && prodserver.mcp.jsonrpc.isNonFiniteNumberSchema(a)
        tf = false;
        return
    end
    types = string(a.type);
    tf = any(types == t | (t == "number" & types == "integer"));
end

function k = kindOf(schema)
% "array" if SCHEMA allows only arrays, "scalar" if it allows no array, and
% "" if it says neither: no schema, no type, or alternatives.
    k = "";
    if ~isstruct(schema) || ~isscalar(schema) || ~isfield(schema, 'type') || ...
            isfield(schema, 'anyOf') || isfield(schema, 'oneOf')
        return
    end
    types = string(schema.type);
    if all(types == "array")
        k = "array";
    elseif ~any(types == "array")
        k = "scalar";
    end
end

function tf = hasType(schema, t)
    tf = isfield(schema, 'type') && any(string(schema.type) == t);
end

function item = itemSchema(schema)
% The schema of a cell's elements: its items', if it has one schema for all.
    item = [];
    if kindOf(schema) == "array" && isfield(schema, 'items') && ...
            isstruct(schema.items) && isscalar(schema.items)
        item = schema.items;
    end
end
