function y = toyScalarOne(x)
%toyScalarOne Test function that adds one to its input. Both input and
%output are scalar double-precision numbers. 

% Copyright 2026, The MathWorks, Inc.

    arguments(Input)
        x (1,1) double  % A scalar double.
    end
    arguments(Output)
        y (1,1) double  % The result. One more than the input.
    end

    y = x + 1;

end