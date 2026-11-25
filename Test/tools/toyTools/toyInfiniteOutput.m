function y = toyInfiniteOutput(x)
%toyInfiniteOutput Test function whose output is infinite for some inputs:
%the reciprocal of its input. Finite for x ~= 0, Inf for x = 0, which
%nothing in its declaration can say.

% Copyright 2026 The MathWorks, Inc.

    arguments(Input)
        x (1,1) double  % A scalar double.
    end
    arguments(Output)
        y (1,1) double  % The reciprocal of x.
    end

    y = 1 / x;

end
