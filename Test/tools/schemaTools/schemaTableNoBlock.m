function [T, nrows] = schemaTableNoBlock(names, ages, city)
% Build a table from parallel arrays and filter by city.

% Copyright 2026 The MathWorks, Inc.

    T = table(names(:), ages(:), repmat(string(city), numel(names), 1), ...
        VariableNames=["Name","Age","City"]);
    nrows = height(T);
end
