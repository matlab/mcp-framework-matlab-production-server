function tf = isnothing(x)
%isnothing Is the input one of the many possible permutations of "not a
%thing"? Nothing must be true for every element of x. :-)

% Copyright (c) 2025 The MathWorks, Inc.

    % Tests valid for all data types
    tf = isempty(x) || all(ismissing(x));
    
    % Not empty or missing, try data type-specific tests.
    if tf == false
        if isstring(x)
            tf = all(strlength(x) == 0);
        elseif isnumeric(x)
            tf = all(isnan(x));
        elseif iscategorical(x)
            tf = all(isundefined(x));
        end
    end
end