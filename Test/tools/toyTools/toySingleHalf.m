function [r, v] = toySingleHalf(x, xs)
% Halve a single and a single array.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) single    % Value
        xs (1,:) single   % Values
    end
    arguments(Output)
        r (1,1) single    % Half of x
        v (1,:) single    % Half of xs
    end
    r = x/2;
    v = xs/2;
end
