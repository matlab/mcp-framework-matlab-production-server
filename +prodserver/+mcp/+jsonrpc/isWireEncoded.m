function tf = isWireEncoded(x)
% isWireEncoded Does x represent a wire-encoded value?

% Copyright 2026 The MathWorks, Inc.

    tf = false;

    % If x is a string, it must be a scalar because it has to convert
    % without ambiguity to char.
    if isstring(x)
        if isscalar(x)
            x = char(x);
        else
            return;
        end
    end

    % If x is a char, it must jsondecode to a structure.
    if ischar(x)
        try
            x = jsondecode(x);
        catch
            return;
        end
    end

    % Scalars (numeric, logical) are always valid wire-encoded values.
    if (isnumeric(x) || islogical(x)) && isscalar(x)
        tf = true;
        return;
    end

    if ~isstruct(x)
        return;
    end

    fields = fieldnames(x);

    % Complex scalar: exactly {"re","im"}, no "type" field.
    if isfield(x, 're') && isfield(x, 'im') && ~isfield(x, 'type')
        tf = numel(fields) == 2;
        return;
    end

    % Duration scalar: {"type":"duration","seconds":N}
    if isfield(x, 'type') && isfield(x, 'seconds') && ...
            strcmp(x.type, 'duration') && ~isfield(x, 'size')
        tf = numel(fields) == 2;
        return;
    end

    % Typed wrapper: must have type+size+data, may have known extra fields.
    if isfield(x, 'type') && isfield(x, 'size') && isfield(x, 'data')
        knownFields = ["type", "size", "data", ...
            "im", "tz", "categories", "ordinal", "fields", ...
            "rows", "variables", "rowTimes", "rowNames", "timeName"];
        tf = isempty(setdiff(fields, knownFields));
        return;
    end

    % Table: {"type":"table","rows":N,"variables":[...]}
    if isfield(x, 'type') && isfield(x, 'variables') && isfield(x, 'rows')
        knownFields = ["type", "rows", "variables", "rowNames"];
        tf = isempty(setdiff(fields, knownFields));
        return;
    end

    % Timetable: {"type":"timetable","rows":N,"rowTimes":...,"variables":[...]}
    if isfield(x, 'type') && isfield(x, 'rowTimes') && isfield(x, 'variables')
        knownFields = ["type", "rows", "rowTimes", "variables", "timeName"];
        tf = isempty(setdiff(fields, knownFields));
        return;
    end

end
