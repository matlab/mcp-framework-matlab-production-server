function n = toyUnsized(names)
%toyUnsized Count names. The input has no declared size, so its schema is
%an array of strings, and a single name must still be accepted.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        names string   % Names to count
    end
    arguments(Output)
        n (1,1) double % How many names
    end

    n = numel(names);
end
