function u = uniqueSchemas(schemas)
%uniqueSchemas The distinct schemas in a cell array, in order.
%   u = uniqueSchemas(schemas) removes each schema equal (isequal) to one
%   before it. The schemas are structs, which unique can't compare.

% Copyright 2026 The MathWorks, Inc.

    u = {};
    for k = 1:numel(schemas)
        if ~any(cellfun(@(s) isequal(s, schemas{k}), u))
            u{end+1} = schemas{k}; %#ok<AGROW>
        end
    end
end
