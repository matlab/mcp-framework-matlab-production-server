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
            'Cannot encode value of class "%s". Supported classes are: ' + ...
            'numeric, logical, char, string, struct, cell, datetime, ' + ...
            'duration, calendarDuration, categorical, table, timetable.', ...
            class(value));
    end
end

% =========================================================================
% NUMERIC
% =========================================================================
function j = encodeNumeric(value)

    cls = class(value);

    % Validate class is one of the supported numeric types.
    supported = {'double','single','int8','int16','int32','int64', ...
                 'uint8','uint16','uint32','uint64'};
    if ~ismember(cls, supported)
        error('prodserver:mcp:unsupportedNumericType', ...
            'Numeric class "%s" is not supported by the MCP encoding.', cls);
    end

    isReal = isreal(value);

    % Scalar real — bare value where possible.
    if isscalar(value) && isReal
        j = encodeScalarDouble(value);
        return
    end

    % Scalar complex — bare {"re","im"} object.
    if isscalar(value) && ~isReal
        j = struct('re', encodeScalarDouble(real(value)), ...
                   'im', encodeScalarDouble(imag(value)));
        return
    end

    % Array — typed wrapper.
    j = struct();
    j.type = cls;
    j.size = size(value);  % [rows, cols, ...]

    if isReal
        j.data = flattenRowMajor(value, @encodeNumericElement);
    else
        j.data = flattenRowMajor(real(value), @encodeNumericElement);
        j.im   = flattenRowMajor(imag(value), @encodeNumericElement);
    end
    end

    % Encode a single numeric element, handling NaN/Inf as strings.
    function v = encodeNumericElement(x)
    if isnan(x)
        v = "NaN";
    elseif isinf(x) && x > 0
        v = "Inf";
    elseif isinf(x) && x < 0
        v = "-Inf";
    else
        v = double(x);  % jsonencode needs double for non-integer JSON numbers
    end
end

% Encode a scalar double for a bare value or re/im field.
function v = encodeScalarDouble(x)
    if isnan(x)
        v = "NaN";
    elseif isinf(x) && x > 0
        v = "Inf";
    elseif isinf(x) && x < 0
        v = "-Inf";
    else
        v = double(x);
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

    % Row vector (1×N) or scalar (1×1) — bare string.
    if isrow(value)
        j = string(value);
        return
    end

    % Multi-row char matrix — typed wrapper, individual characters row-major.
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
            j = struct('type','string','size',[1,1],'data',{value});  
        end
        return
    end

    j = struct();
    j.type = 'string';
    j.size = size(value);
    % missing() → JSON null via jsonencode when stored as {missing} in a cell.
    j.data = flattenRowMajor(value, @(s) encodeStringElement(s));
end

function v = encodeStringElement(s)
    if ismissing(s)
        v = {missing};   % jsonencode converts missing in a cell to null
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
        % Scalar struct — plain JSON object.
        j = struct();
        for k = 1:numel(fields)
            f = fields{k};
            j.(f) = encodeValue(value.(f));
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
    idx = rowMajorIndices(size(value));
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

    idx = rowMajorIndices(size(value));
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

    % Determine timezone string once.
    tz = value.TimeZone;  % '' for unzoned, 'UTC', or IANA name

    if isscalar(value)
        j = datetimeToIso(value, tz);
        return
    end

    j = struct();
    j.type = 'datetime';
    j.size = size(value);
    if ~isempty(tz) && ~strcmpi(tz, 'UTC')
        j.tz = tz;
    end

    idx = rowMajorIndices(size(value));
    strs = cell(1, numel(value));
    for k = 1:numel(value)
        strs{k} = datetimeToIso(value(idx(k)), tz);
    end
    j.data = strs;
end

function s = datetimeToIso(dt, tz)
    % Format a scalar datetime as an ISO 8601 string.
    if isnat(dt)
        s = 'NaT';
        return
    end
    if isempty(tz)
        % Unzoned — no suffix.
        s = char(datetime(dt, 'Format', "yyyy-MM-dd'T'HH:mm:ss.SSS"));
    elseif strcmpi(tz, 'UTC')
        s = char(datetime(dt, 'Format', "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", ...
            'TimeZone', 'UTC'));
    else
        % IANA zone — include offset suffix and embed tz in array wrapper.
        s = char(datetime(dt, 'Format', "yyyy-MM-dd'T'HH:mm:ss.SSSXXX", ...
            'TimeZone', tz));
    end
end

% =========================================================================
% DURATION
% =========================================================================
function j = encodeDuration(value)

    if isa(value, 'calendarDuration')
        error('prodserver:mcp:unsupportedDurationType', ...
            'calendarDuration cannot be encoded losslessly as seconds. ' + ...
            'Convert to duration before encoding, or represent as a struct ' + ...
            'with year/month/day fields.');
    end

    seconds_val = seconds(value);  % Convert to numeric seconds

    if isscalar(value)
        j = struct('type', 'duration', 'seconds', encodeNumericElement(seconds_val));
        return
    end

    j = struct();
    j.type = 'duration';
    j.size = size(value);
    j.data = flattenRowMajor(seconds_val, @encodeNumericElement);
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

    idx = rowMajorIndices(size(value));
    elements = cell(1, numel(value));
    for k = 1:numel(value)
        el = value(idx(k));
        if isundefined(el)
            elements{k} = {missing};  % → JSON null
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

    varNames = value.Properties.VariableNames;
    vars = cell(1, numel(varNames));
    for k = 1:numel(varNames)
        vname = varNames{k};
        col   = value.(vname);
        entry = struct('name', vname, 'value', encodeValue(col));
        vars{k} = entry;
    end
    j.variables = vars;
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

    varNames = value.Properties.VariableNames;
    vars = cell(1, numel(varNames));
    for k = 1:numel(varNames)
        vname = varNames{k};
        col   = value.(vname);
        entry = struct('name', vname, 'value', encodeValue(col));
        vars{k} = entry;
    end
    j.variables = vars;
end

% =========================================================================
% UTILITIES
% =========================================================================

function flat = flattenRowMajor(value, encodeFn)
    %FLATTENROWMAJOR  Return a cell array of encoded elements in row-major order.

    idx = rowMajorIndices(size(value));
    flat = cell(1, numel(value));
    for k = 1:numel(value)
        flat{k} = encodeFn(value(idx(k)));
    end
end

function idx = rowMajorIndices(sz)
    %ROWMAJORINDICES  Linear indices that visit elements in row-major order.
    %
    %   MATLAB's default linear indexing is column-major (first index varies
    %   fastest). Row-major (last index varies fastest) requires a permutation.
    %
    %   For a 2-D array this is equivalent to iterating (row, col) with col
    %   varying in the inner loop. For N-D it generalises to last dim fastest.

    if isscalar(sz)
        sz = [sz 1];
    end

    ndim = numel(sz);
    if ndim == 1 || prod(sz) == 0
        idx = 1:prod(sz);
        return
    end

    % Build N-D grid of subscripts in row-major order, then convert to linear.
    % Row-major: last dimension varies fastest → permute order is [ndim, ndim-1, ..., 1]
    % relative to MATLAB's native column-major ndgrid output.

    grids = cell(1, ndim);
    ranges = arrayfun(@(n) 1:n, sz, 'UniformOutput', false);
    [grids{:}] = ndgrid(ranges{:});  % column-major grids

    % Flatten each grid and interleave in row-major order.
    % Row-major traversal: vary last subscript fastest.
    % ndgrid gives us grids where grids{1} varies fastest (col-major).
    % We want grids{end} to vary fastest, so we permute the order.
    permOrder = ndim:-1:1;
    subs = cell(1, ndim);
    for d = 1:ndim
        g = grids{d};
        g = permute(g, permOrder);
        subs{d} = g(:)';
    end
    idx = sub2ind(sz, subs{:});
end
