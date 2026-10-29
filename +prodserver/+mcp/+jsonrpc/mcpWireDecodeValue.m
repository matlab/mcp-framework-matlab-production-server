function value = mcpWireDecodeValue(j)
%mcpWireDecodeValue  Apply MCP type-aware decoding to a jsondecode'd value.
%
%   VALUE = mcpWireDecodeValue(J) decodes J, which must be a MATLAB value
%   already produced by jsondecode() from an MCP wire-encoded JSON value,
%   back to the original MATLAB value.
%
%   This is the structural-decoding step of mcpWireDecode. It is exposed
%   as a public function so that callers who need to decode individual
%   fields within a larger jsondecode'd struct (e.g. the structuredContent
%   fields of a tools/call response) can do so without re-serialising the
%   value to a JSON string first.
%
%   Decoding rules (applied in order)
%   ----------------------------------
%   []  (jsondecode null)          → error
%   logical scalar                 → logical scalar
%   numeric scalar                 → double scalar
%   "NaN" / "Inf" / "-Inf"         → double special value
%   other string                   → datetime (if ISO 8601) else char row vector
%   struct with "type" field       → dispatch on type
%   struct with "re" and "im"      → complex double scalar
%   struct without "type"          → scalar struct (fields decoded recursively)
%   cell / numeric array from JSON → error (never produced by this encoding)
%
%   See also: mcpWireDecode, mcpWireEncodeValue, jsondecode

% Copyright 2025-2026 The MathWorks, Inc.

    value = decodeValue(j);
end

% =========================================================================
function value = decodeValue(j)

% Rule 1: null  →  jsondecode gives [] for JSON null.
if isempty(j) && ~isstruct(j) && ~iscell(j) && ~ischar(j) && ~isstring(j)
    error('prodserver:mcp:nullNotAllowed', ...
        "JSON null is not a valid standalone MCP-encoded MATLAB value. " + ...
        "null is only valid inside string arrays and categorical data.");
end

% Rule 2: boolean scalar.
if islogical(j) && isscalar(j)
    value = j;
    return
end

% Rule 3: numeric scalar  →  double.
if isnumeric(j) && isscalar(j) && ~isstruct(j)
    value = double(j);
    return
end

% Rule 4 & 5: string values.
if ischar(j) || (isstring(j) && isscalar(j))
    value = decodeString(j);
    return
end

% Rules 6-8: struct (object).
if isstruct(j)
    value = decodeStruct(j);
    return
end

% Rule 9: bare JSON array or anything else — encoding error.
error('prodserver:mcp:invalidEncoding', ...
    "Encountered a bare JSON array or unrecognised value type ""%s"". " + ...
    "Bare JSON arrays are never produced by the MCP encoding. " + ...
    "Ensure the value was encoded with matlabToMcpJson.", class(j));
end

% =========================================================================
% STRING DISPATCH  (rules 4 and 5)
% =========================================================================
function value = decodeString(j)

    % J is char or string at this point.
    s = j;
    
    % Special float and NaT sentinels.
    [value, ok] = specialFloat(s);
    if ok
        return
    end
    if string(s) == prodserver.mcp.MCPConstants.NaTText
        value = NaT;
        return
    end
    
    % Attempt ISO 8601 datetime parse.
    [dt, ok] = prodserver.mcp.jsonrpc.parseISODateTime(s);
    if ok
        value = dt;
        return
    end

    % Fall through: treat as char vector or string scalar
    value = s;
end

% =========================================================================
% STRUCT DISPATCH  (rules 6, 7, 8)
% =========================================================================
function value = decodeStruct(j)

% Rule 7: complex scalar — has "re" and "im", no "type".
if isfield(j, 're') && isfield(j, 'im') && ~isfield(j, 'type')
    re = decodeScalarFloat(j.re);
    im = decodeScalarFloat(j.im);
    value = complex(re, im);
    return
end

% Rule 6: typed wrapper.
if prodserver.mcp.jsonrpc.isMcpTypedWrapper(j)
    value = decodeTyped(j);
    return
end

% Rule 8: plain struct — decode fields recursively.
value = decodeScalarStruct(j);
end

% =========================================================================
% TYPED WRAPPER DISPATCH
% =========================================================================
function value = decodeTyped(j)

    t = j.type;
    
    switch t
        case cellstr(prodserver.mcp.internal.Constants.NumericClasses)
            value = decodeNumericArray(j);
    
        case 'logical'
            value = decodeLogicalArray(j);
    
        case 'char'
            value = decodeCharMatrix(j);
    
        case 'string'
            value = decodeStringArray(j);
    
        case 'struct'
            value = decodeStructArray(j);
    
        case 'cell'
            value = decodeCellArray(j);
    
        case 'datetime'
            value = decodeDatetimeArray(j);
    
        case 'duration'
            value = decodeDurationArray(j);
    
        case 'categorical'
            value = decodeCategoricalArray(j);
    
        case 'table'
            value = decodeTable(j);
    
        case 'timetable'
            value = decodeTimetable(j);
    
        otherwise
            error('prodserver:mcp:unknownType', ...
                "Unknown MCP type discriminator '%s'. " +  ...
                "Supported types are: %s.", t, strjoin( ...
                prodserver.mcp.jsonrpc.WireSupport.classNames(), ", "));
    end
end

% =========================================================================
% NUMERIC ARRAYS
% =========================================================================
function value = decodeNumericArray(j)

    sz   = validateSize(j);
    data = j.data;
    
    validateDataLength(data, sz, j.type);
    
    % Decode flat row-major data, handling NaN/Inf sentinels.
    n = prod(sz);
    flat = decodeNumericFlat(data, n);
    
    % Handle complex.
    if isfield(j, 'im')
        validateDataLength(j.im, n, [j.type ' (im)']);
        flatIm = decodeNumericFlat(j.im, n);
        flat   = complex(flat, flatIm);
    end
    
    % Reshape row-major flat vector into MATLAB array (column-major memory).
    value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
    
    % Cast to target type (complex integers are not supported in MATLAB, so
    % only cast real arrays; complex arrays stay as double).
    if isreal(flat)
        value = cast(value, j.type);
    end
end

function flat = decodeNumericFlat(data, n)
%DECODENUMERICFLAT  Decode a cell or numeric array of encoded numeric elements.

flat = zeros(1, n);
if isnumeric(data) && ~iscell(data)
    % Pure numeric JSON array — no sentinels possible.
    flat = double(data(:)');
    return
end
if ~iscell(data)
    data = num2cell(data);
end
for k = 1:n
    flat(k) = decodeScalarFloat(data{k});
end
end

function v = decodeScalarFloat(x)
%DECODESCALARFLOAT  Decode one numeric element, handling sentinel strings.
if ischar(x) || isstring(x)
    [v, ok] = specialFloat(x);
    if ~ok
        error('prodserver:mcp:invalidNumericSentinel', ...
            "Invalid numeric sentinel string ""%s"". " + ...
            "Only %s are permitted.", char(x), sentinels());
    end
elseif isnumeric(x) && isscalar(x)
    v = double(x);
else
    error('prodserver:mcp:invalidNumericElement', ...
        "Numeric data array contains an element of unexpected type ""%s"". " + ...
        "Elements must be numbers or the sentinel strings %s.", ...
        class(x), sentinels());
end
end

function [v, ok] = specialFloat(text)
% The number a sentinel string stands for -- NaN, Inf or -Inf -- and
% whether TEXT is one.
    [ok, k] = ismember(string(text), prodserver.mcp.MCPConstants.SpecialFloatText);
    values = [NaN Inf -Inf];
    v = [];
    if ok
        v = values(k);
    end
end

function text = sentinels()
% "NaN", "Inf" and "-Inf", for messages.
    text = prodserver.mcp.internal.andList( ...
        """" + prodserver.mcp.MCPConstants.SpecialFloatText + """");
end

% =========================================================================
% LOGICAL ARRAYS
% =========================================================================
function value = decodeLogicalArray(j)

    sz   = validateSize(j);
    data = j.data;
    validateDataLength(data, sz, 'logical');
    
    if ~iscell(data)
        data = num2cell(data);
    end
    n = prod(sz);
    flat = false(1, n);
    for k = 1:n
        el = data{k};
        if ~islogical(el) && ~(isnumeric(el) && (el == 0 || el == 1))
            error('prodserver:mcp:invalidLogicalElement', ...
                "logical data array element %d has value ""%s"" which is not " + ...
                "a JSON boolean (true/false).", k, mat2str(el));
        end
        flat(k) = logical(el);
    end
    
    value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
end

% =========================================================================
% CHAR MATRIX
% =========================================================================
function value = decodeCharMatrix(j)

    sz = validateSize(j);
    n  = prod(sz);
    
    if n == 0
        value = char(zeros(sz));
        return
    end
    
    data = j.data;
    validateDataLength(data, sz, 'char');
    
    if ~iscell(data)
        data = num2cell(data);
    end
    
    flat = char(zeros(1, n));
    for k = 1:n
        el = data{k};
        if (~ischar(el) && ~isstring(el)) || strlength(string(el)) ~= 1
            error('prodserver:mcp:invalidCharElement', ...
                'char data array element %d must be a single character, got "%s".', ...
                k, mat2str(el));
        end
        flat(k) = char(el);
    end
    
    value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
end

% =========================================================================
% STRING ARRAYS
% =========================================================================
function value = decodeStringArray(j)

    sz = validateSize(j);
   
    data = j.data;
    validateDataLength(data, sz, 'string');
    
    if ~iscell(data)
        if ischar(data) && isvector(data)
            data = { data };
        else
            data = num2cell(data);
        end
    end
    
    n  = prod(sz);
    flat = strings(1, n);
    for k = 1:n
        el = data{k};
        if ~ischar(el) && ~isstring(el) && (isempty(el) || all(isnan(el)))
            % JSON null → jsondecode gives [NaN] → missing string.
            flat(k) = missing;
        elseif ischar(el) || isstring(el)
            flat(k) = string(el);
        else
            error('prodserver:mcp:invalidStringElement', ...
                ['string data array element %d must be a string or null, ' ...
                'got "%s".'], ...
                k, class(el));
        end
    end
    
    value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
end

% =========================================================================
% STRUCT ARRAY
% =========================================================================
function value = decodeStructArray(j)

    sz = validateSize(j);
    n  = prod(sz);
    
    % Empty struct array.
    if n == 0
        if isfield(j, 'fields') && ~isempty(j.fields)
            fnames = cellstr(j.fields);
            args   = [fnames; repmat({{}}, 1, numel(fnames))];
            value  = struct(args{:});
            value  = reshape(value, sz);
        else
            value = reshape(struct(), sz);
        end
        return
    end
    
    data = j.data;
    validateDataLength(data, sz, 'struct');
    
    % Decode elements (row-major order) and build struct array.
    elements = cell(1, n);
    for k = 1:n
        el = data(k);
        elements{k} = decodeScalarStruct(el);
    end
    
    % Assemble into a struct array in row-major order.
    value = prodserver.mcp.jsonrpc.fromRowMajor([elements{:}], sz);
end

function value = decodeScalarStruct(j)
%DECODESCALARSTRUCT  Decode a plain JSON object as a scalar struct.
fields = fieldnames(j);
value  = struct();
for k = 1:numel(fields)
    f         = fields{k};
    value.(f) = decodeValue(j.(f));
end
end

% =========================================================================
% CELL ARRAY
% =========================================================================
function value = decodeCellArray(j)

    sz = validateSize(j);
    n  = prod(sz);

    if n == 0
        value = reshape({}, sz);
        return
    end

    data = j.data;
    if ~iscell(data)
        data = num2cell(data);
    end
    validateDataLength(data, sz, 'cell');

    flat = cell(1, n);
    for k = 1:n
        flat{k} = decodeValue(data{k});
    end

    value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
end

% =========================================================================
% DATETIME ARRAY
% =========================================================================
function value = decodeDatetimeArray(j)

    sz = validateSize(j);
    
    tz = '';
    if isfield(j, 'tz')
        tz = char(j.tz);
    end
    
    data = j.data;
    validateDataLength(data, sz, 'datetime');
    
    if ~iscell(data)
        data = num2cell(data);
    end
    data = reshape(data, 1, []);
    
    isText = cellfun(@(el) ischar(el) || isstring(el), data);
    if ~all(isText)
        k = find(~isText, 1);
        error('prodserver:mcp:invalidDatetimeElement', ...
            'datetime data array element %d must be an ISO 8601 string, got "%s".', ...
            k, class(data{k}));
    end
    isNaT = strcmp(data, prodserver.mcp.MCPConstants.NaTText);

    % One parse for the whole array. Each string has its own offset; tz,
    % if given, names the zone they are in.
    [flat, ok, ~, mixed] = prodserver.mcp.jsonrpc.parseISODateTime(data);
    bad = find(~ok & ~isNaT, 1);
    if isempty(bad) && mixed
        bad = find(ok, 1);
    end
    if ~isempty(bad)
        error('prodserver:mcp:invalidDatetimeString', ...
            "datetime data array element %d (""%s"") could not be parsed " + ...
            "as an ISO 8601 datetime in the array's time zone.", bad, ...
            string(data{bad}));
    end
    if ~isempty(tz)
        flat.TimeZone = tz;
    end

    value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
end

% =========================================================================
% DURATION
% =========================================================================
function value = decodeDurationArray(j)

    % Scalar form: {"type":"duration","seconds":N}
    if isfield(j, 'seconds') && ~isfield(j, 'size')
        s = decodeScalarFloat(j.seconds);
        value = seconds(s);
        return
    end
    
    sz = validateSize(j);
    data = j.data;
    validateDataLength(data, sz, 'duration');

    % Seconds, with the same NaN/Inf sentinels as numeric data.
    flat  = prodserver.mcp.jsonrpc.fromRowMajor(decodeNumericFlat(data, prod(sz)), sz);
    value = seconds(flat);
end

% =========================================================================
% CATEGORICAL
% =========================================================================
function value = decodeCategoricalArray(j)

sz = validateSize(j);
n  = prod(sz);

if ~isfield(j, 'categories')
    error('prodserver:mcp:missingField', ...
        'categorical wrapper is missing required field "categories".');
end

% jsondecode gives an empty list as [], not an empty cell: no categories,
% as for an array that is all <undefined>.
if isempty(j.categories)
    cats = cell(0, 1);
else
    cats = cellstr(j.categories);
end
isOrd   = isfield(j, 'ordinal') && j.ordinal;
data    = j.data;
validateDataLength(data, sz, 'categorical');

if ~iscell(data)
    data = num2cell(data);
end

% Build flat cell array of strings / <undefined>.
flatStrs = cell(1, n);
for k = 1:n
    el = data{k};
    if isempty(el) && ~ischar(el) && ~isstring(el)
        flatStrs{k} = '';     % will become <undefined>
    elseif ischar(el) || isstring(el)
        flatStrs{k} = char(el);
    elseif all(isnan(el))
        flatStrs{k} = '';
    else
        error('prodserver:mcp:invalidCategoricalElement', ...
            'categorical data array element %d must be a category string or null.', k);
    end
end

% Create categorical preserving category order.
flat  = categorical(flatStrs, cats, 'Ordinal', isOrd);
% Elements that were null (empty string, not in cats) become <undefined>.
flat(strcmp(flatStrs, '') & ~ismember('', cats)) = missing;

value = prodserver.mcp.jsonrpc.fromRowMajor(flat, sz);
end

% =========================================================================
% TABLE
% =========================================================================
function value = decodeTable(j)

if ~isfield(j, 'variables')
    error('prodserver:mcp:missingField', ...
        'table wrapper is missing required field "variables".');
end

[names, columns] = decodeVariables(j.variables, 'table', 'Table');

value = table(columns{:}, 'VariableNames', names);

if isfield(j, 'rowNames') && ~isempty(j.rowNames)
    value.Properties.RowNames = cellstr(j.rowNames);
end
end

% =========================================================================
% TIMETABLE
% =========================================================================
function value = decodeTimetable(j)

if ~isfield(j, 'rowTimes')
    error('prodserver:mcp:missingField', ...
        'timetable wrapper is missing required field "rowTimes".');
end
if ~isfield(j, 'variables')
    error('prodserver:mcp:missingField', ...
        'timetable wrapper is missing required field "variables".');
end

rowTimes = decodeValue(j.rowTimes);
if ~isa(rowTimes, 'datetime') && ~isa(rowTimes, 'duration')
    error('prodserver:mcp:invalidRowTimes', ...
        'timetable "rowTimes" decoded to class "%s"; expected datetime or duration.', ...
        class(rowTimes));
end

[names, columns] = decodeVariables(j.variables, 'timetable', 'Timetable');

value = timetable(columns{:}, 'RowTimes', rowTimes(:), ...
    'VariableNames', names);
% Time column may have non-default name.
if isfield(j,'timeName')
    value.Properties.DimensionNames{1} = j.timeName;
end
end

function [names, columns] = decodeVariables(vars, noun, idNoun)
%DECODEVARIABLES  The names and decoded values of a table's or timetable's
%variables. NOUN and IDNOUN name the class in the message and the error ID.
if ~iscell(vars)
    vars = num2cell(vars);
end
nVars   = numel(vars);
names   = cell(1, nVars);
columns = cell(1, nVars);
for k = 1:nVars
    v = vars{k};
    if ~isfield(v, 'name') || ~isfield(v, 'value')
        error("prodserver:mcp:invalid" + idNoun + "Variable", ...
            '%s variable %d is missing "name" or "value" field.', noun, k);
    end
    names{k}   = char(v.name);
    columns{k} = decodeValue(v.value);
end
end

% =========================================================================
% UTILITIES
% =========================================================================

function sz = validateSize(j)
%VALIDATESIZE  Extract and validate the "size" field from a typed wrapper.

if ~isfield(j, 'size')
    error('prodserver:mcp:missingField', ...
        'Typed wrapper for "%s" is missing required field "size".', j.type);
end

% (:)' flattens to a column then transposes to a row, normalising
% both column-vector sizes (produced by jsondecode on nested objects)
% and row-vector sizes alike. reshape() requires a row vector.
sz = double(j.size(:)');

if numel(sz) < 2 || any(sz < 0) || any(sz ~= floor(sz))
    error('prodserver:mcp:invalidSize', ...
        "Field ""size"" in ""%s"" wrapper must be a vector of at least two " + ...
        "non-negative integers; got %s.", j.type, mat2str(sz));
end
end

function validateDataLength(data, sz, typeName)
%VALIDATEDATALENGTH  Check that data has the right number of elements.

    expected = prod(sz);
    actual = numel(data);

    if strcmp(typeName,"string")
        % We know data is supposed to be a string. But the jsondecode 
        % turned data into a char array. Which will make validateDataLength
        % fail. So a bit of trickery to compute the size.
        if ischar(data)
            if isvector(data)
                % A char vector becomes a scalar string; numel == 1.
                actual = 1;
            end
        end
    end
    
    if actual ~= expected
        szStr = strjoin(string(sz),",");
        error('prodserver:mcp:dataLengthMismatch', ...
            ['"%s" wrapper: "size" [%s] implies %d elements but "data" ' ...
            'contains %d.'], ...
            typeName, szStr, expected, actual);
    end
end
