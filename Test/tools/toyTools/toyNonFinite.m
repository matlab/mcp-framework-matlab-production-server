function [s, v] = toyNonFinite(kind)
% Return a scalar and a vector that may hold NaN, Inf or -Inf, or one element.

% Copyright 2026 The MathWorks, Inc.
    arguments (Input)
        kind (1,1) string    % finite, nan, inf, vecnan, vecinf or one.
    end
    arguments (Output)
        s (1,1) double       % The scalar result.
        v (1,:) double       % The vector result.
    end
    s = 1;
    v = [1 2];
    switch kind
        case "nan"
            s = NaN;
        case "inf"
            s = Inf;
        case "vecnan"
            v = [1 NaN];
        case "vecinf"
            v = [-Inf 1 Inf NaN];
        case "one"
            v = 5;
    end
end
