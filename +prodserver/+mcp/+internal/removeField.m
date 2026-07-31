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
    
    % Handle struct arrays by recursing element-wise
    if numel(S) > 1
        for idx = 1:numel(S)
            S(idx) = removeField(S(idx), fn); %#ok<AGROW>
        end
        return
    end
    
    % Remove matching top-level field if present
    if isfield(S, fn)
        S = rmfield(S, fn);
    end
    
    % Recurse into remaining fields
    fields = fieldnames(S);
    for k = 1:numel(fields)
        f = fields{k};
        val = S.(f);
    
        % Only handle the most primitive container types here.
        % Tables and dictionaries containing structures, for example, are
        % not processed recursively. (But add branches for them if
        % necessary -- which it shouldn't be, because the definition
        % structure upon which this is called does not contain either of
        % those types.)
        if isstruct(val)
            % Recurse for nested struct or struct array
            S.(f) = removeField(val, fn);
        elseif iscell(val)
            % Recurse into cells that contain structs (preserve non-structs)
            for c = 1:numel(val)
                if isstruct(val{c})
                    val{c} = removeField(val{c}, fn);
                end
            end
            S.(f) = val;
        end
    end
end