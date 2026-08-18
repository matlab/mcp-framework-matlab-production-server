function S = removeField(S, fieldName)
% removeField Remove all occurrences of a field from a nested struct
%   S = removeField(S, fieldName) returns S with every field named
%   fieldName removed at any nesting level. S may be a struct scalar or
%   struct array. fieldName may be a char or string scalar.

% Copyright 2026 The MathWorks, Inc.

    arguments
        S struct
        fieldName (1,1) string
    end
    fn = char(fieldName);

    % Remove matching top-level field if present (works on arrays too)
    if isfield(S, fn)
        S = rmfield(S, fn);
    end

    % Recurse into remaining fields
    fields = fieldnames(S);
    for k = 1:numel(fields)
        f = fields{k};
        for idx = 1:numel(S)
            val = S(idx).(f);
            if isstruct(val)
                S(idx).(f) = prodserver.mcp.internal.removeField(val, fn);
            elseif iscell(val)
                for c = 1:numel(val)
                    if isstruct(val{c})
                        val{c} = prodserver.mcp.internal.removeField(val{c}, fn);
                    end
                end
                S(idx).(f) = val;
            end
        end
    end
end
