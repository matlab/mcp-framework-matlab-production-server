function j = mcpWireEncodeValue(value)
%mcpWireEncodeValue  Transform a MATLAB value into a JSON-compatible structure.
%
%   J = mcpWireEncodeValue(VALUE) applies the MCP wire-encoding rules to
%   VALUE and returns a MATLAB struct, cell, or scalar that can be passed
%   directly to jsonencode() to produce the MCP wire encoding (spec v1.1).
%
%   This is the structural-transformation step of mcpWireEncode.  It is
%   exposed as a public function so that callers who need to embed an
%   encoded MATLAB value inside a larger struct (and serialise the whole
%   thing with a single jsonencode call) can do so without the extra
%   JSON serialisation round-trip.
%
%   Encoding summary
%   ----------------
%   Scalars                  Bare JSON primitives (no wrapper)
%   Numeric/logical arrays   {"type","size","data"} — data row-major
%   char row vector          Bare string
%   char matrix (M>1)        {"type":"char","size","data"} — row-major chars
%   string array             {"type":"string","size","data"}
%   scalar struct            Plain JSON object, fields encoded recursively
%   struct array             {"type":"struct","size","data"}
%   cell array               {"type":"cell","size","data"}
%   datetime scalar          Bare ISO 8601 string
%   datetime array           {"type":"datetime","size","data"}
%   duration scalar          {"type":"duration","seconds":s}
%   duration array           {"type":"duration","size","data"}
%   categorical              {"type":"categorical","size","categories","data"}
%   table                    {"type":"table","rows","variables":[...]}
%   timetable                {"type":"timetable","rows","rowTimes","variables":[...]}
%
%   Error IDs all use the prefix  prodserver:mcp
%
%   See also: mcpWireEncode, mcpWireDecode, jsonencode

% Copyright 2025-2026 The MathWorks, Inc.

    j = encodeValue(value);
end

% =========================================================================
function j = encodeValue(value)

% Dispatch on class, most specific first.
    if isnumeric(value)
        j = encodeNumeric(value);
    elseif islogical(value)
        j = encodeLogical(value);
    elseif ischar(value)
        j = encodeChar(value);
    elseif isstring(value)
        j = encodeString(value);
    elseif isstruct(value)
        j = encodeStruct(value);
    elseif iscell(value)
        j = encodeCell(value);
    elseif isa(value, 'datetime')
        j = encodeDatetime(value);
    elseif isa(value, 'duration') || isa(value, 'calendarDuration')
        j = encodeDuration(value);
    elseif isa(value, 'categorical')
        j = encodeCategorical(value);
    elseif isa(value, 'table')
        j = encodeTable(value);
    elseif isa(value, 'timetable')
        j = encodeTimetable(value);
    else
        error('prodserver:mcp:unsupportedType', ...
            "Cannot encode value of class '%s'. Supported classes are: %s.", ...
            class(value), strjoin(prodserver.mcp.jsonrpc.WireSupport.classNames(), ", "));
    end
end

% =========================================================================
% NUMERIC
% =========================================================================
function j = encodeNumeric(value)

    cls = class(value);

    % Validate class is one of the supported numeric types.
    if ~ismember(cls, prodserver.mcp.internal.Constants.NumericClasses)
        error('prodserver:mcp:unsupportedNumericType', ...
            'Numeric class "%s" is not supported by the MCP encoding.', cls);
    end

    isReal = isreal(value);

    % Scalar real — bare value where possible.
    if isscalar(value) && isReal
        j = encodeNumber(value);
        return
    end

    % Scalar complex — bare {"re","im"} object.
    if isscalar(value) && ~isReal
        j = struct('re', encodeNumber(real(value)), ...
                   'im', encodeNumber(imag(value)));
        return
    end

    % Array — typed wrapper.
    j = struct();
    j.type = cls;
    j.size = size(value);  % [rows, cols, ...]

    if isReal
        j.data = flattenRowMajor(value, @encodeNumber);
    else
        j.data = flattenRowMajor(real(value), @encodeNumber);
        j.im   = flattenRowMajor(imag(value), @encodeNumber);
    end
end

% Encode one number: a bare value, a re/im field or an array element.
% NaN and Inf have no JSON literal, so they are strings.
function v = encodeNumber(x)
    import prodserver.mcp.MCPConstants
    if isnan(x)
        v = MCPConstants.NaNText;
    elseif isinf(x) && x > 0
        v = MCPConstants.InfText;
    elseif isinf(x) && x < 0
        v = MCPConstants.NegInfText;
    else
        v = double(x);  % jsonencode needs double for non-integer JSON numbers
    end
end

% =========================================================================
% LOGICAL
% =========================================================================
function j = encodeLogical(value)

    if isscalar(value)
        % Bare boolean — jsonencode will render as true/false.
        j = logical(value);
        return
    end

    j = struct();
    j.type = 'logical';
    j.size = size(value);
    j.data = flattenRowMajor(value, @(x) logical(x));
end

% =========================================================================
% CHAR
% =========================================================================
function j = encodeChar(value)

    if isempty(value)
        % Empty char — use typed wrapper so shape is preserved.
        j = struct('type', 'char', 'size', size(value), 'data', {{}});
        return
    end

    % Row vector (1×N) or scalar (1×1) — bare string, unless the decoder
    % would read that text as something else: a date-time, or NaN, Inf,
    % -Inf or NaT. Then it takes the wrapper below.
    if isrow(value) && ~readsAsOtherValue(value)
        j = string(value);
        return
    end

    % Multi-row char matrix, or text that needs it — typed wrapper,
    % individual characters row-major.
    j = struct();
    j.type = 'char';
    j.size = size(value);
    j.data = flattenRowMajor(value, @(c) string(c));
end

% =========================================================================
% STRING
% =========================================================================
function j = encodeString(value)

    if isscalar(value)
        if ismissing(value)
            % A scalar missing string has no natural bare representation;
            % use a 1×1 typed wrapper so the missing is preserved.
            j = struct('type', 'string', 'size', [1 1], 'data', {{missing}});
        else
            % data is an array, even of one: so the rules say, and so the
            % published schema describes it (see wrapInvertible).
            j = struct('type','string','size',[1,1],'data',{{value}});
        end
        return
    end

    j = struct();
    j.type = 'string';
    j.size = size(value);
    % missing() → JSON null via jsonencode when stored as {missing} in a cell.
    j.data = flattenRowMajor(value, @(s) encodeStringElement(s));
end

function tf = readsAsOtherValue(text)
% True if mcpWireDecodeValue would decode bare TEXT as something other than
% text: a special float, NaT or an ISO 8601 date-time.
    C = prodserver.mcp.MCPConstants;
    tf = ismember(string(text), [C.SpecialFloatText, C.NaTText]);
    if ~tf
        [~, tf] = prodserver.mcp.jsonrpc.parseISODateTime(text);
    end
end

function v = encodeStringElement(s)
    if ismissing(s)
        % jsonencode writes a missing element of a cell as null. Not
        % {missing}: in the cell of elements, that is [null].
        v = missing;
    else
        v = s;
    end
end


% =========================================================================
% STRUCT
% =========================================================================
function j = encodeStruct(value)

    fields = fieldnames(value);

    if isscalar(value)
        if prodserver.mcp.jsonrpc.isMcpTypedWrapper(value)
            % Scalar struct whose fields collide with MCP typed-wrapper
            % fields — force struct-array encoding to avoid ambiguity.
            j = struct();
            j.type = 'struct';
            j.size = [1 1];
            el = struct();
            for k = 1:numel(fields)
                f = fields{k};
                el.(f) = encodeValue(value.(f));
            end
            j.data = {el};
        else
            % Scalar struct — plain JSON object.
            j = struct();
            for k = 1:numel(fields)
                f = fields{k};
                j.(f) = encodeValue(value.(f));
            end
        end
        return
    end

    if isempty(value)
        % Empty struct array — typed wrapper with fields list.
        j = struct();
        j.type   = 'struct';
        j.size   = size(value);
        j.fields = fields;
        j.data   = {};
        return
    end

    % Non-scalar struct array — typed wrapper, elements row-major.
    j = struct();
    j.type = 'struct';
    j.size = size(value);

    % Flatten in row-major order.
    idx = prodserver.mcp.jsonrpc.rowMajorOrder(size(value));
    elements = cell(1, numel(value));
    for k = 1:numel(value)
        el = struct();
        for fi = 1:numel(fields)
            f = fields{fi};
            el.(f) = encodeValue(value(idx(k)).(f));
        end
        elements{k} = el;
    end
    j.data = elements;
end

% =========================================================================
% CELL
% =========================================================================
function j = encodeCell(value)

    j = struct();
    j.type = 'cell';
    j.size = size(value);

    if isempty(value)
        j.data = {};
        return
    end

    idx = prodserver.mcp.jsonrpc.rowMajorOrder(size(value));
    elements = cell(1, numel(value));
    for k = 1:numel(value)
        elements{k} = encodeValue(value{idx(k)});
    end
    j.data = elements;
end

% =========================================================================
% DATETIME
% =========================================================================
function j = encodeDatetime(value)

    % '' for unzoned, 'UTC', or a zone the ISO text can't name -- its
    % offset is not a zone -- which goes in the wrapper's tz.
    tz = value.TimeZone;
    namedZone = ~isempty(tz) && ~strcmpi(tz, 'UTC');

    % A scalar is bare ISO text, unless its zone needs naming.
    if isscalar(value) && ~namedZone
        j = char(prodserver.mcp.jsonrpc.isoDateTimeText(value, ...
            prodserver.mcp.MCPConstants.NaTText));
        return
    end

    j = struct();
    j.type = 'datetime';
    j.size = size(value);
    if namedZone
        j.tz = tz;
    end

    idx = prodserver.mcp.jsonrpc.rowMajorOrder(size(value));
    text = prodserver.mcp.jsonrpc.isoDateTimeText(value(idx), ...
        prodserver.mcp.MCPConstants.NaTText);
    j.data = cellstr(reshape(text, 1, []));
end

% =========================================================================
% DURATION
% =========================================================================
function j = encodeDuration(value)

    if isa(value, 'calendarDuration')
        error('prodserver:mcp:unsupportedDurationType', ...
            ['calendarDuration cannot be encoded losslessly as seconds. ' ...
            'Convert to duration before encoding, or represent as a struct ' ...
            'with year/month/day fields.']);
    end

    seconds_val = seconds(value);  % Convert to numeric seconds

    if isscalar(value)
        j = struct('type', 'duration', 'seconds', encodeNumber(seconds_val));
        return
    end

    j = struct();
    j.type = 'duration';
    j.size = size(value);
    j.data = flattenRowMajor(seconds_val, @encodeNumber);
end

% =========================================================================
% CATEGORICAL
% =========================================================================
function j = encodeCategorical(value)

    cats     = categories(value);   % cell array of category strings
    isOrd    = isordinal(value);

    j = struct();
    j.type       = 'categorical';
    j.size       = size(value);
    j.categories = cats;
    if isOrd
        j.ordinal = true;
    end

    idx = prodserver.mcp.jsonrpc.rowMajorOrder(size(value));
    elements = cell(1, numel(value));
    for k = 1:numel(value)
        el = value(idx(k));
        if isundefined(el)
            elements{k} = missing;  % → JSON null (not [null])
        else
            elements{k} = char(el);
        end
    end
    j.data = elements;
end

% =========================================================================
% TABLE
% =========================================================================
function j = encodeTable(value)

    j = struct();
    j.type = 'table';
    j.rows = height(value);

    rn = value.Properties.RowNames;
    if ~isempty(rn)
        j.rowNames = rn;
    end

    j.variables = encodeVariables(value);
end

% =========================================================================
% TIMETABLE
% =========================================================================
function j = encodeTimetable(value)

    j = struct();
    j.type     = 'timetable';
    j.rows     = height(value);
    j.rowTimes = encodeValue(value.Properties.RowTimes);
    j.timeName = value.Properties.DimensionNames{1}; % Allow non-default
    j.variables = encodeVariables(value);
end

% The variables of a table or timetable: one encoded value per variable.
function vars = encodeVariables(value)
    varNames = value.Properties.VariableNames;
    vars = cell(1, numel(varNames));
    for k = 1:numel(varNames)
        vars{k} = struct('name', varNames{k}, ...
            'value', encodeValue(value.(varNames{k})));
    end
end

% =========================================================================
% UTILITIES
% =========================================================================

function flat = flattenRowMajor(value, encodeFn)
    %FLATTENROWMAJOR  Return a cell array of encoded elements in row-major order.

    idx = prodserver.mcp.jsonrpc.rowMajorOrder(size(value));
    flat = cell(1, numel(value));
    for k = 1:numel(value)
        flat{k} = encodeFn(value(idx(k)));
    end
end
